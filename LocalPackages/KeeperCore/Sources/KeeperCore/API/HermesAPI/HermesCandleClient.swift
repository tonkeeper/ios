import Foundation
import TKKandelabrAPI
import TKLogging

final class HermesCandleClient: HermesCandleStreaming, @unchecked Sendable {
    private let socketFactory: HermesSocketFactory
    private let sleep: @Sendable (TimeInterval) async -> Void

    init(
        hostProvider: APIHostProvider,
        urlSession: URLSession,
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: UInt64(nanoseconds * 1_000_000_000))
        }
    ) {
        socketFactory = HermesSocketFactory(hostProvider: hostProvider, urlSession: urlSession)
        self.sleep = sleep
    }

    func watch(
        feedId: String,
        onUpdate: @escaping @Sendable (Components.Schemas.GetCandlesResponse) async -> Void,
        onSubscribed: @escaping @Sendable () async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) -> HermesCandleWatch {
        let session = Session(
            socketFactory: socketFactory,
            feedId: feedId,
            sleep: sleep,
            onUpdate: onUpdate,
            onSubscribed: onSubscribed,
            onReconnecting: onReconnecting,
            onRejected: onRejected
        )
        Task { await session.start() }
        return HermesCandleWatch(onCancel: { Task { await session.cancel() } })
    }
}

private actor Session {
    private let socketFactory: HermesSocketFactory
    private let feedId: String
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let onUpdate: @Sendable (Components.Schemas.GetCandlesResponse) async -> Void
    private let onSubscribed: @Sendable () async -> Void
    private let onReconnecting: @Sendable () async -> Void
    private let onRejected: @Sendable () async -> Void

    private var task: Task<Void, Never>?
    private var webSocket: URLSessionWebSocketTask?
    private var nextRequestId: Int64 = 0
    private var cancelled = false

    init(
        socketFactory: HermesSocketFactory,
        feedId: String,
        sleep: @escaping @Sendable (TimeInterval) async -> Void,
        onUpdate: @escaping @Sendable (Components.Schemas.GetCandlesResponse) async -> Void,
        onSubscribed: @escaping @Sendable () async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) {
        self.socketFactory = socketFactory
        self.feedId = feedId
        self.sleep = sleep
        self.onUpdate = onUpdate
        self.onSubscribed = onSubscribed
        self.onReconnecting = onReconnecting
        self.onRejected = onRejected
    }

    func start() {
        guard task == nil, !cancelled else { return }
        task = Task { await run() }
    }

    func cancel() {
        cancelled = true
        let current = webSocket
        webSocket = nil
        task?.cancel()
        task = nil
        send(channel: HermesChannel.unsubscribe, name: HermesMessageName.unsubscribe, payload: ["feedId": feedId], on: current)
        current?.cancel(with: .normalClosure, reason: nil)
    }

    private func run() async {
        var backoff = Self.minBackoff
        while !Task.isCancelled {
            if cancelled { return }
            let subscribed: Bool
            do {
                subscribed = try await connectOnce()
            } catch is CancellationError {
                return
            } catch {
                Log.w("🪵 Perps: hermes session failed — \(error)")
                subscribed = false
            }
            if cancelled { return }
            await onReconnecting()
            if subscribed {
                backoff = Self.minBackoff
            }
            await sleep(backoff)
            backoff = min(backoff * 2, Self.maxBackoff)
        }
    }

    private func connectOnce() async throws -> Bool {
        let socket = try await socketFactory.makeTask()
        webSocket = socket
        nextRequestId = 0
        socket.resume()
        defer {
            if webSocket === socket {
                webSocket = nil
            }
            socket.cancel(with: .goingAway, reason: nil)
        }

        if cancelled || Task.isCancelled { return false }

        let subscribeRequestId = send(
            channel: HermesChannel.subscribe,
            name: HermesMessageName.subscribe,
            payload: ["feedId": feedId],
            on: socket
        )

        let pingTask = Task {
            while !Task.isCancelled {
                await sleep(Self.pingInterval)
                guard !Task.isCancelled else { return }
                ping(on: socket)
            }
        }
        defer { pingTask.cancel() }

        let subscribeTimeoutTask = Task { [sleep] in
            await sleep(Self.subscribeTimeout)
            guard !Task.isCancelled else { return }
            socket.cancel(with: .goingAway, reason: nil)
        }
        defer { subscribeTimeoutTask.cancel() }

        var subscribed = false
        var bufferedUpdates: [Components.Schemas.GetCandlesResponse] = []
        while !Task.isCancelled, !cancelled {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await socket.receive()
            } catch {
                if cancelled || Task.isCancelled { return subscribed }
                throw error
            }
            guard let data = message.data else { continue }
            switch HermesCandleCodec.event(from: data) {
            case let .candles(response):
                if subscribed {
                    await onUpdate(response)
                } else {
                    bufferedUpdates.append(response)
                }
            case let .subscribed(requestId):
                guard !subscribed, requestId == nil || requestId == subscribeRequestId else { continue }
                subscribed = true
                subscribeTimeoutTask.cancel()
                await onSubscribed()
                for response in bufferedUpdates {
                    await onUpdate(response)
                }
                bufferedUpdates.removeAll(keepingCapacity: false)
            case .retryableFailure:
                return subscribed
            case .rejected:
                await onRejected()
                cancel()
                return subscribed
            case .ignored:
                continue
            }
        }
        return subscribed
    }

    private func ping(on socket: URLSessionWebSocketTask) {
        guard !cancelled, webSocket === socket else { return }
        send(channel: HermesChannel.ping, name: HermesMessageName.ping, payload: nil, on: socket)
    }

    @discardableResult
    private func send(
        channel: String,
        name: String,
        payload: [String: String]?,
        on socket: URLSessionWebSocketTask?
    ) -> Int64? {
        guard let socket else { return nil }
        nextRequestId += 1
        let reqid = nextRequestId
        do {
            let data = try HermesCandleCodec.request(channel: channel, name: name, reqid: reqid, payload: payload)
            guard let text = String(data: data, encoding: .utf8) else { return nil }
            socket.send(.string(text)) { [weak self] error in
                guard let error else { return }
                Task { await self?.sendFailed(error, socket: socket) }
            }
        } catch {
            Log.w("🪵 Perps: hermes encode failed — \(error)")
        }
        return reqid
    }

    private func sendFailed(_ error: Error, socket: URLSessionWebSocketTask) {
        guard webSocket === socket else { return }
        Log.w("🪵 Perps: hermes send failed — \(error)")
        socket.cancel(with: .goingAway, reason: nil)
    }

    private static let pingInterval: TimeInterval = 120
    private static let subscribeTimeout: TimeInterval = 30
    private static let minBackoff: TimeInterval = 1
    private static let maxBackoff: TimeInterval = 30
}
