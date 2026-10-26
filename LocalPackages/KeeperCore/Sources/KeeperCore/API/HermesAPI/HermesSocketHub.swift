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

    convenience init(hostProvider: APIHostProvider, urlSession: URLSession) {
        let socketFactory = HermesSocketFactory(hostProvider: hostProvider, urlSession: urlSession)
        self.init(makeSocket: { try await socketFactory.makeTask() })
    }

    init(
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        },
        makeSocket: @escaping @Sendable () async throws -> any HermesSocket
    ) {
        self.sleep = sleep
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
        let socket: any HermesSocket
        do {
            socket = try await makeSocket()
        } catch {
            Log.perps.w("hermes connect failed — \(error)")
            return false
        }
        socket.resume()
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

        do {
            while !Task.isCancelled {
                guard let data = try await socket.receive().data else { continue }
                logIfError(data)
                for listener in lock.withLock({ Array(listeners.values) }) {
                    await listener.onFrame(data)
                }
            }
        } catch {
            if !Task.isCancelled {
                Log.perps.w("hermes session failed — \(error)")
            }
        }
        return lock.withLock { healthy }
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
    private static let minBackoff: TimeInterval = 1
    private static let maxBackoff: TimeInterval = 30
}
