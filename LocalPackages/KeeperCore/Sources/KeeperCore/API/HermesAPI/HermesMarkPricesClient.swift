import Foundation
import TKLogging

protocol HermesMarkPricesStreaming: AnyObject, Sendable {
    func watch(
        onUpdate: @escaping @Sendable (HermesMarkPricesSnapshot) async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) -> HermesMarkPricesWatch
}

struct HermesMarkPricesSnapshot: Sendable {
    let tickers: [String]
    let prices: [HermesTickerPrice]
}

struct HermesMarkPricesWatch: Sendable {
    private let onSetTickers: @Sendable ([String]) -> Void
    private let onCancel: @Sendable () -> Void

    init(
        onSetTickers: @escaping @Sendable ([String]) -> Void,
        onCancel: @escaping @Sendable () -> Void
    ) {
        self.onSetTickers = onSetTickers
        self.onCancel = onCancel
    }

    func setTickers(_ tickers: [String]) {
        onSetTickers(tickers)
    }

    func cancel() {
        onCancel()
    }
}

final class HermesMarkPricesClient: HermesMarkPricesStreaming, @unchecked Sendable {
    private enum Command: Sendable {
        case setTickers([String])
        case cancel
    }

    private let socketFactory: HermesSocketFactory
    private let cooldown: String
    private let sleep: @Sendable (TimeInterval) async -> Void

    init(
        hostProvider: APIHostProvider,
        urlSession: URLSession,
        cooldown: String = "PT2S",
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: UInt64(nanoseconds * 1_000_000_000))
        }
    ) {
        socketFactory = HermesSocketFactory(hostProvider: hostProvider, urlSession: urlSession)
        self.cooldown = cooldown
        self.sleep = sleep
    }

    func watch(
        onUpdate: @escaping @Sendable (HermesMarkPricesSnapshot) async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) -> HermesMarkPricesWatch {
        let (commands, continuation) = AsyncStream.makeStream(of: Command.self)
        let session = Session(
            socketFactory: socketFactory,
            cooldown: cooldown,
            sleep: sleep,
            onUpdate: onUpdate,
            onReconnecting: onReconnecting,
            onRejected: onRejected,
            onTerminated: { continuation.finish() }
        )
        Task {
            for await command in commands {
                switch command {
                case let .setTickers(tickers):
                    await session.setTickers(tickers)
                case .cancel:
                    await session.cancel()
                }
            }
        }
        return HermesMarkPricesWatch(
            onSetTickers: { continuation.yield(.setTickers($0)) },
            onCancel: { continuation.yield(.cancel) }
        )
    }
}

private actor Session {
    private struct Subscription {
        let requestId: Int64
        let tickers: [String]
    }

    private let socketFactory: HermesSocketFactory
    private let cooldown: String
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let onUpdate: @Sendable (HermesMarkPricesSnapshot) async -> Void
    private let onReconnecting: @Sendable () async -> Void
    private let onRejected: @Sendable () async -> Void
    private let onTerminated: @Sendable () -> Void

    private var desiredTickers: [String] = []
    private var runTask: Task<Void, Never>?
    private var webSocket: URLSessionWebSocketTask?
    private var pendingSubscription: Subscription?
    private var acceptedTickers: [String]?
    private var subscribeTimeoutTask: Task<Void, Never>?
    private var nextRequestId: Int64 = 0
    private var cancelled = false

    init(
        socketFactory: HermesSocketFactory,
        cooldown: String,
        sleep: @escaping @Sendable (TimeInterval) async -> Void,
        onUpdate: @escaping @Sendable (HermesMarkPricesSnapshot) async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void,
        onTerminated: @escaping @Sendable () -> Void
    ) {
        self.socketFactory = socketFactory
        self.cooldown = cooldown
        self.sleep = sleep
        self.onUpdate = onUpdate
        self.onReconnecting = onReconnecting
        self.onRejected = onRejected
        self.onTerminated = onTerminated
    }

    func setTickers(_ tickers: [String]) {
        guard !cancelled, tickers != desiredTickers else { return }
        desiredTickers = tickers
        if tickers.isEmpty {
            stopConnection()
        } else if runTask == nil {
            runTask = Task { await run() }
        } else if let webSocket, pendingSubscription == nil {
            sendSubscribe(on: webSocket)
        }
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        stopConnection()
        onTerminated()
    }

    private func stopConnection() {
        let socket = webSocket
        webSocket = nil
        pendingSubscription = nil
        acceptedTickers = nil
        subscribeTimeoutTask?.cancel()
        subscribeTimeoutTask = nil
        runTask?.cancel()
        runTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
    }

    private func run() async {
        var backoff = Self.minBackoff
        while !Task.isCancelled {
            if cancelled || desiredTickers.isEmpty { return }
            let subscribed: Bool
            do {
                subscribed = try await connectOnce()
            } catch is CancellationError {
                return
            } catch {
                Log.w("🪵 Perps: hermes prices session failed — \(error)")
                subscribed = false
            }
            if cancelled || desiredTickers.isEmpty { return }
            await onReconnecting()
            if subscribed {
                backoff = Self.minBackoff
            }
            await sleep(backoff)
            backoff = min(backoff * 2, Self.maxBackoff)
        }
    }

    private func connectOnce() async throws -> Bool {
        if cancelled || Task.isCancelled || desiredTickers.isEmpty { return false }

        let socket = try await socketFactory.makeTask()
        webSocket = socket
        pendingSubscription = nil
        acceptedTickers = nil
        socket.resume()
        defer {
            if webSocket === socket {
                webSocket = nil
            }
            socket.cancel(with: .goingAway, reason: nil)
        }

        sendSubscribe(on: socket)

        let pingTask = Task {
            while !Task.isCancelled {
                await sleep(Self.pingInterval)
                guard !Task.isCancelled else { return }
                ping(on: socket)
            }
        }
        defer { pingTask.cancel() }

        defer {
            subscribeTimeoutTask?.cancel()
            subscribeTimeoutTask = nil
        }

        var subscribed = false
        while !Task.isCancelled, !cancelled {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await socket.receive()
            } catch {
                if cancelled || Task.isCancelled { return subscribed }
                throw error
            }
            guard let data = message.data else { continue }
            let frame = HermesMarkPricesCodec.frame(from: data)
            switch frame.event {
            case let .prices(prices):
                guard let acceptedTickers else { continue }
                await onUpdate(HermesMarkPricesSnapshot(tickers: acceptedTickers, prices: prices))
            case .subscribed:
                guard let pending = matchingPending(requestId: frame.requestId) else { continue }
                acceptedTickers = pending.tickers
                pendingSubscription = nil
                cancelSubscribeTimeout()
                subscribed = true
                if acceptedTickers != desiredTickers {
                    sendSubscribe(on: socket)
                }
            case .declined:
                guard let declined = matchingPending(requestId: frame.requestId) else { continue }
                pendingSubscription = nil
                cancelSubscribeTimeout()
                if declined.tickers != desiredTickers {
                    sendSubscribe(on: socket)
                }
            case .retryableFailure:
                guard matchingPending(requestId: frame.requestId) != nil else { continue }
                return subscribed
            case .rejected:
                guard matchingPending(requestId: frame.requestId) != nil else { continue }
                cancel()
                await onRejected()
                return subscribed
            case .ignored:
                continue
            }
        }
        return subscribed
    }

    private func sendSubscribe(on socket: URLSessionWebSocketTask) {
        let tickers = desiredTickers
        guard !tickers.isEmpty, pendingSubscription == nil else { return }
        nextRequestId += 1
        let reqid = nextRequestId
        do {
            let data = try HermesMarkPricesCodec.subscribeRequest(
                tickers: tickers,
                cooldown: cooldown,
                reqid: reqid
            )
            guard let text = String(data: data, encoding: .utf8) else { return }
            pendingSubscription = Subscription(
                requestId: reqid,
                tickers: tickers
            )
            startSubscribeTimeout(requestId: reqid, socket: socket)
            socket.send(.string(text)) { [weak self] error in
                guard let error else { return }
                Task { await self?.subscribeSendFailed(error, requestId: reqid, socket: socket) }
            }
        } catch {
            Log.w("🪵 Perps: hermes prices encode failed — \(error)")
        }
    }

    private func matchingPending(requestId: Int64?) -> Subscription? {
        guard let pendingSubscription else { return nil }
        if let requestId {
            guard requestId == pendingSubscription.requestId else { return nil }
        }
        return pendingSubscription
    }

    private func startSubscribeTimeout(requestId: Int64, socket: URLSessionWebSocketTask) {
        subscribeTimeoutTask?.cancel()
        subscribeTimeoutTask = Task { [weak self, sleep] in
            await sleep(Self.subscribeTimeout)
            guard !Task.isCancelled else { return }
            await self?.subscribeTimedOut(requestId: requestId, socket: socket)
        }
    }

    private func cancelSubscribeTimeout() {
        subscribeTimeoutTask?.cancel()
        subscribeTimeoutTask = nil
    }

    private func subscribeTimedOut(requestId: Int64, socket: URLSessionWebSocketTask) {
        guard webSocket === socket, pendingSubscription?.requestId == requestId else { return }
        socket.cancel(with: .goingAway, reason: nil)
    }

    private func subscribeSendFailed(_ error: Error, requestId: Int64, socket: URLSessionWebSocketTask) {
        guard webSocket === socket, pendingSubscription?.requestId == requestId else { return }
        Log.w("🪵 Perps: hermes prices send failed — \(error)")
        socket.cancel(with: .goingAway, reason: nil)
    }

    private func ping(on socket: URLSessionWebSocketTask) {
        guard !cancelled, webSocket === socket else { return }
        nextRequestId += 1
        do {
            let data = try HermesMarkPricesCodec.pingRequest(reqid: nextRequestId)
            guard let text = String(data: data, encoding: .utf8) else { return }
            socket.send(.string(text)) { [weak self] error in
                guard let error else { return }
                Task { await self?.socketSendFailed(error, socket: socket, operation: "ping") }
            }
        } catch {
            Log.w("🪵 Perps: hermes prices encode failed — \(error)")
        }
    }

    private func socketSendFailed(_ error: Error, socket: URLSessionWebSocketTask, operation: String) {
        guard webSocket === socket else { return }
        Log.w("🪵 Perps: hermes prices \(operation) failed — \(error)")
        socket.cancel(with: .goingAway, reason: nil)
    }

    private static let pingInterval: TimeInterval = 120
    private static let subscribeTimeout: TimeInterval = 30
    private static let minBackoff: TimeInterval = 1
    private static let maxBackoff: TimeInterval = 30
}
