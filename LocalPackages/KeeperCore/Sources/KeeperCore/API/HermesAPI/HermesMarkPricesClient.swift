import Foundation

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

final class HermesMarkPricesClient: HermesMarkPricesStreaming, Sendable {
    private enum Command: Sendable {
        case setTickers([String])
        case cancel
    }

    private let hub: HermesSocketHub
    private let cooldown: String
    private let sleep: @Sendable (TimeInterval) async -> Void

    init(
        hub: HermesSocketHub,
        cooldown: String = "PT2S",
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: UInt64(nanoseconds * 1_000_000_000))
        }
    ) {
        self.hub = hub
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
            hub: hub,
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

    private let id = UUID()
    private let hub: HermesSocketHub
    private let cooldown: String
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let onUpdate: @Sendable (HermesMarkPricesSnapshot) async -> Void
    private let onReconnecting: @Sendable () async -> Void
    private let onRejected: @Sendable () async -> Void
    private let onTerminated: @Sendable () -> Void

    private var desiredTickers: [String] = []
    private var attached = false
    private var connected = false
    private var pendingSubscription: Subscription?
    private var acceptedTickers: [String]?
    private var subscribeTimeoutTask: Task<Void, Never>?
    private var retryDelay = Session.minRetryDelay
    private var retryTask: Task<Void, Never>?
    private var cancelled = false

    init(
        hub: HermesSocketHub,
        cooldown: String,
        sleep: @escaping @Sendable (TimeInterval) async -> Void,
        onUpdate: @escaping @Sendable (HermesMarkPricesSnapshot) async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void,
        onTerminated: @escaping @Sendable () -> Void
    ) {
        self.hub = hub
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
        } else if !attached {
            attached = true
            let listener = HermesSocketListener(
                onConnected: { await self.didConnect() },
                onFrame: { await self.receive($0) },
                onDisconnected: { await self.didDisconnect() }
            )
            if hub.attach(id, listener) {
                didConnect()
            }
        } else if connected, pendingSubscription == nil {
            sendSubscribe()
        }
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        stopConnection()
        onTerminated()
    }

    private func stopConnection() {
        hub.unsubscribe(Self.pricesKey, by: id) {
            try HermesRequest.encode(
                channel: HermesMarkPricesChannel.unsubscribe,
                name: HermesMarkPricesMessageName.unsubscribe,
                reqid: $0
            )
        }
        if attached {
            hub.detach(id)
        }
        attached = false
        resetConnection()
    }

    private func resetConnection() {
        connected = false
        pendingSubscription = nil
        acceptedTickers = nil
        cancelSubscribeTimeout()
        retryTask?.cancel()
        retryTask = nil
        retryDelay = Self.minRetryDelay
    }

    private func didConnect() {
        guard !cancelled, attached else { return }
        resetConnection()
        connected = true
        sendSubscribe()
    }

    private func didDisconnect() async {
        guard !cancelled, attached else { return }
        resetConnection()
        await onReconnecting()
    }

    private func receive(_ data: Data) async {
        guard connected else { return }
        let frame = HermesMarkPricesCodec.frame(from: data)
        switch frame.event {
        case let .prices(prices):
            guard let acceptedTickers else { return }
            await onUpdate(HermesMarkPricesSnapshot(tickers: acceptedTickers, prices: prices))
        case .subscribed:
            guard let pending = matchingPending(requestId: frame.requestId) else { return }
            hub.markHealthy()
            acceptedTickers = pending.tickers
            pendingSubscription = nil
            cancelSubscribeTimeout()
            retryDelay = Self.minRetryDelay
            if acceptedTickers != desiredTickers {
                sendSubscribe()
            }
        case .declined:
            guard let declined = matchingPending(requestId: frame.requestId) else { return }
            pendingSubscription = nil
            cancelSubscribeTimeout()
            if declined.tickers != desiredTickers {
                sendSubscribe()
            }
        case .retryableFailure:
            guard matchingPending(requestId: frame.requestId) != nil else { return }
            pendingSubscription = nil
            cancelSubscribeTimeout()
            retryLater()
        case .rejected:
            guard matchingPending(requestId: frame.requestId) != nil else { return }
            cancel()
            await onRejected()
        case .ignored:
            return
        }
    }

    private func sendSubscribe() {
        let tickers = desiredTickers
        guard !tickers.isEmpty, pendingSubscription == nil else { return }
        let encode: (Int64) throws -> Data = { [cooldown] in
            try HermesMarkPricesCodec.subscribeRequest(tickers: tickers, cooldown: cooldown, reqid: $0)
        }
        guard let reqid = hub.subscribe(Self.pricesKey, by: id, encode) else { return }
        pendingSubscription = Subscription(requestId: reqid, tickers: tickers)
        startSubscribeTimeout(requestId: reqid)
    }

    private func matchingPending(requestId: Int64?) -> Subscription? {
        guard let pendingSubscription else { return nil }
        if let requestId {
            guard requestId == pendingSubscription.requestId else { return nil }
        }
        return pendingSubscription
    }

    private func startSubscribeTimeout(requestId: Int64) {
        subscribeTimeoutTask?.cancel()
        subscribeTimeoutTask = Task { [weak self, sleep] in
            await sleep(Self.subscribeTimeout)
            guard !Task.isCancelled else { return }
            await self?.subscribeTimedOut(requestId: requestId)
        }
    }

    private func cancelSubscribeTimeout() {
        subscribeTimeoutTask?.cancel()
        subscribeTimeoutTask = nil
    }

    private func subscribeTimedOut(requestId: Int64) {
        guard pendingSubscription?.requestId == requestId else { return }
        pendingSubscription = nil
        retryLater()
    }

    private func retryLater() {
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, Self.maxRetryDelay)
        retryTask?.cancel()
        retryTask = Task { [weak self, sleep] in
            await sleep(delay)
            guard !Task.isCancelled else { return }
            await self?.retrySubscribe()
        }
    }

    private func retrySubscribe() {
        guard connected, acceptedTickers != desiredTickers else { return }
        sendSubscribe()
    }

    private static let pricesKey = HermesMarkPricesChannel.subscribe
    private static let subscribeTimeout: TimeInterval = 30
    private static let minRetryDelay: TimeInterval = 1
    private static let maxRetryDelay: TimeInterval = 30
}
