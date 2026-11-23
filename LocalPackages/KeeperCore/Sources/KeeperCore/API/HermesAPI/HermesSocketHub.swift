import Foundation
import TKLogging

protocol HermesSocket: AnyObject, Sendable {
    func resume()
    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping @Sendable ((any Error)?) -> Void)
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

extension URLSessionWebSocketTask: HermesSocket {}

struct HermesSocketListener: Sendable {
    let onConnected: @Sendable () async -> Void
    let onFrame: @Sendable (Data) async -> Void
    let onDisconnected: @Sendable () async -> Void
}

final class HermesSocketHub: @unchecked Sendable {
    private struct ErrorPayload: Decodable {
        let code: String?
        let description: String?
    }

    private let deviceAuth: DeviceAuthProviding
    private let makeSocket: @Sendable () async throws -> any HermesSocket
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let lock = NSLock()
    private var listeners: [UUID: HermesSocketListener] = [:]
    private var holders: [String: Set<UUID>] = [:]
    private var socket: (any HermesSocket)?
    private var runTask: Task<Void, Never>?
    private var backoffTask: Task<Void, Never>?
    private var skipBackoff = false
    private var healthy = false
    private var nextRequestId: Int64 = 0
    private var staleToken: String?
    private var renewedToken: String?
    private var renewing = false

    convenience init(hostProvider: APIHostProvider, urlSession: URLSession, deviceAuth: DeviceAuthProviding) {
        let socketFactory = HermesSocketFactory(hostProvider: hostProvider, urlSession: urlSession)
        self.init(deviceAuth: deviceAuth, makeSocket: { try await socketFactory.makeTask() })
    }

    init(
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        },
        deviceAuth: DeviceAuthProviding,
        makeSocket: @escaping @Sendable () async throws -> any HermesSocket
    ) {
        self.sleep = sleep
        self.deviceAuth = deviceAuth
        self.makeSocket = makeSocket
    }

    func attach(_ id: UUID, _ listener: HermesSocketListener) -> Bool {
        lock.withLock {
            listeners[id] = listener
            if runTask == nil {
                runTask = Task { await run() }
            } else if socket == nil {
                skipBackoff = true
                backoffTask?.cancel()
            }
            return socket != nil
        }
    }

    func detach(_ id: UUID) {
        lock.withLock {
            listeners[id] = nil
            guard listeners.isEmpty else { return }
            runTask?.cancel()
            runTask = nil
            backoffTask?.cancel()
            socket?.cancel(with: .normalClosure, reason: nil)
            socket = nil
            holders = [:]
            renewing = false
        }
    }

    func subscribe(_ key: String, by id: UUID, _ encode: (Int64) throws -> Data) -> Int64? {
        lock.withLock {
            let requestId = sendLocked(encode)
            if requestId != nil {
                holders[key, default: []].insert(id)
            }
            return requestId
        }
    }

    func unsubscribe(_ key: String, by id: UUID, _ encode: (Int64) throws -> Data) {
        lock.withLock {
            guard holders[key]?.remove(id) != nil, holders[key]?.isEmpty == true else { return }
            holders[key] = nil
            sendLocked(encode)
        }
    }

    func markHealthy() {
        lock.withLock { healthy = true }
    }

    @discardableResult
    private func sendLocked(_ encode: (Int64) throws -> Data) -> Int64? {
        guard let socket else { return nil }
        nextRequestId += 1
        do {
            guard let text = try String(data: encode(nextRequestId), encoding: .utf8) else { return nil }
            socket.send(.string(text)) { [weak self] error in
                guard let error else { return }
                Task { self?.sendFailed(error, on: socket) }
            }
            return nextRequestId
        } catch {
            Log.perps.w("hermes encode failed — \(error)")
            return nil
        }
    }

    private func sendFailed(_ error: any Error, on socket: any HermesSocket) {
        guard lock.withLock({ self.socket === socket }) else { return }
        Log.perps.w("hermes send failed — \(error)")
        socket.cancel(with: .goingAway, reason: nil)
    }

    private func run() async {
        var backoff = Self.minBackoff
        while !Task.isCancelled {
            let healthy = await connectOnce()
            guard !Task.isCancelled else { return }
            let renewed = lock.withLock {
                defer { renewing = false }
                return renewing
            }
            if renewed {
                backoff = Self.minBackoff
                continue
            }
            for listener in lock.withLock({ Array(listeners.values) }) {
                await listener.onDisconnected()
            }
            if healthy {
                backoff = Self.minBackoff
            }
            await pause(backoff)
            backoff = min(backoff * 2, Self.maxBackoff)
        }
    }

    private func pause(_ interval: TimeInterval) async {
        let pause: Task<Void, Never>? = lock.withLock {
            guard !skipBackoff else { return nil }
            backoffTask = Task { [sleep] in await sleep(interval) }
            return backoffTask
        }
        await pause?.value
        lock.withLock {
            backoffTask = nil
            skipBackoff = false
        }
    }

    private func connectOnce() async -> Bool {
        guard let session = await deviceSession() else { return false }
        let socket: any HermesSocket
        do {
            socket = try await makeSocket()
        } catch {
            Log.perps.w("hermes connect failed — \(error)")
            return false
        }
        socket.resume()
        guard await logIn(socket, token: session.accessToken) else {
            socket.cancel(with: .goingAway, reason: nil)
            return false
        }
        let connected: [HermesSocketListener]? = lock.withLock {
            guard !Task.isCancelled, !listeners.isEmpty else { return nil }
            self.socket = socket
            holders = [:]
            healthy = false
            skipBackoff = false
            return Array(listeners.values)
        }
        guard let connected else {
            socket.cancel(with: .goingAway, reason: nil)
            return false
        }
        defer {
            lock.withLock {
                if self.socket === socket {
                    self.socket = nil
                }
            }
            socket.cancel(with: .goingAway, reason: nil)
        }
        for listener in connected {
            await listener.onConnected()
        }

        let pingTask = Task { [weak self, sleep] in
            while !Task.isCancelled {
                await sleep(Self.pingInterval)
                guard !Task.isCancelled else { return }
                self?.ping()
            }
        }
        defer { pingTask.cancel() }

        let renewIn = session.expiresAt.timeIntervalSinceNow - Self.tokenRefreshLead
        let renewTask = renewIn > 0 ? Task { [weak self, sleep] in
            await sleep(renewIn)
            guard !Task.isCancelled else { return }
            self?.renewToken(session.accessToken, of: socket)
        } : nil
        defer { renewTask?.cancel() }

        do {
            while !Task.isCancelled {
                guard let data = try await socket.receive().data else { continue }
                logIfError(data)
                for listener in lock.withLock({ Array(listeners.values) }) {
                    await listener.onFrame(data)
                }
            }
        } catch {
            if !Task.isCancelled, !lock.withLock({ renewing }) {
                Log.perps.w("hermes session failed — \(error)")
            }
        }
        return lock.withLock { healthy }
    }

    private func deviceSession() async -> DeviceAuthSession? {
        let stale = lock.withLock { staleToken }
        do {
            var session: DeviceAuthSession
            if let stale {
                session = try await deviceAuth.recoverSession(invalidating: stale)
                lock.withLock { renewedToken = session.accessToken }
            } else {
                session = try await deviceAuth.session()
            }
            if session.expiresAt.timeIntervalSinceNow < Self.tokenRefreshLead {
                session = try await deviceAuth.recoverSession(invalidating: session.accessToken)
            }
            lock.withLock { staleToken = nil }
            return session
        } catch {
            if !Task.isCancelled {
                Log.perps.w("hermes has no device session — \(error)")
            }
            return nil
        }
    }

    private func logIn(_ socket: any HermesSocket, token: String) async -> Bool {
        let reqid = lock.withLock {
            nextRequestId += 1
            return nextRequestId
        }
        let request: Data
        do {
            request = try HermesRequest.encode(
                channel: HermesChannel.login,
                name: HermesMessageName.login,
                reqid: reqid,
                payload: ["token": token]
            )
        } catch {
            Log.perps.w("hermes login encode failed — \(error)")
            return false
        }
        socket.send(.string(String(decoding: request, as: UTF8.self))) { error in
            guard let error else { return }
            Log.perps.w("hermes login send failed — \(error)")
            socket.cancel(with: .goingAway, reason: nil)
        }
        let timeout = Task { [sleep] in
            await sleep(Self.loginTimeout)
            guard !Task.isCancelled else { return }
            socket.cancel(with: .goingAway, reason: nil)
        }
        defer { timeout.cancel() }
        return await withTaskCancellationHandler {
            await loginReply(reqid, token: token, on: socket)
        } onCancel: {
            socket.cancel(with: .goingAway, reason: nil)
        }
    }

    private func loginReply(_ reqid: Int64, token: String, on socket: any HermesSocket) async -> Bool {
        do {
            while true {
                guard let data = try await socket.receive().data,
                      let envelope = try? JSONDecoder().decode(HermesInboundEnvelope<ErrorPayload>.self, from: data),
                      let message = envelope.message,
                      message.reqid == reqid
                else { continue }
                let code = message.payload?.code
                if message.name == HermesMessageName.loginResponse || code == HermesErrorCode.alreadyAuthenticated {
                    lock.withLock { renewedToken = nil }
                    return true
                }
                if code == HermesErrorCode.invalidCredentials {
                    lock.withLock {
                        if token != renewedToken {
                            staleToken = token
                        }
                    }
                    Log.perps.w("hermes login rejected — invalid credentials")
                    return false
                }
                Log.perps.w("hermes login failed — \(message.name ?? "") \(code ?? "") \(message.payload?.description ?? "")")
                return false
            }
        } catch {
            if !Task.isCancelled {
                Log.perps.w("hermes login failed — \(error)")
            }
            return false
        }
    }

    private func renewToken(_ token: String, of socket: any HermesSocket) {
        let isCurrent = lock.withLock {
            guard self.socket === socket else { return false }
            staleToken = token
            renewing = true
            return true
        }
        guard isCurrent else { return }
        socket.cancel(with: .normalClosure, reason: nil)
    }

    private func ping() {
        _ = lock.withLock {
            sendLocked { try HermesRequest.encode(channel: HermesChannel.ping, name: HermesMessageName.ping, reqid: $0) }
        }
    }

    private func logIfError(_ data: Data) {
        guard let envelope = try? JSONDecoder().decode(HermesInboundEnvelope<ErrorPayload>.self, from: data),
              envelope.message?.name == HermesMessageName.errorResponse
              || envelope.message?.name == HermesMessageName.errorMessage
        else { return }
        let payload = envelope.message?.payload
        Log.perps.w("hermes \(envelope.channel ?? "?") error — \(payload?.code ?? "") \(payload?.description ?? "")")
    }

    private static let pingInterval: TimeInterval = 120
    private static let loginTimeout: TimeInterval = 30
    private static let tokenRefreshLead: TimeInterval = 120
    private static let minBackoff: TimeInterval = 1
    private static let maxBackoff: TimeInterval = 30
}
