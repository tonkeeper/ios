import Foundation
import TKKandelabrAPI

final class HermesCandleClient: HermesCandleStreaming, Sendable {
    private let hub: HermesSocketHub
    private let sleep: @Sendable (TimeInterval) async -> Void

    init(
        hub: HermesSocketHub,
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: UInt64(nanoseconds * 1_000_000_000))
        }
    ) {
        self.hub = hub
        self.sleep = sleep
    }

    func watch(
        feedId: String,
        volumeFeedId: String,
        onUpdate: @escaping @Sendable (Components.Schemas.GetCandlesResponse) async -> Void,
        onVolumeUpdate: @escaping @Sendable (Components.Schemas.GetCandlesResponse) async -> Void,
        onSubscribed: @escaping @Sendable () async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) -> HermesCandleWatch {
        let session = Session(
            hub: hub,
            feedId: feedId,
            volumeFeedId: volumeFeedId,
            sleep: sleep,
            onUpdate: onUpdate,
            onVolumeUpdate: onVolumeUpdate,
            onSubscribed: onSubscribed,
            onReconnecting: onReconnecting,
            onRejected: onRejected
        )
        Task { await session.start() }
        return HermesCandleWatch(onCancel: { Task { await session.cancel() } })
    }
}

private actor Session {
    private let id = UUID()
    private let hub: HermesSocketHub
    private let feedId: String
    private let volumeFeedId: String
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let onUpdate: @Sendable (Components.Schemas.GetCandlesResponse) async -> Void
    private let onVolumeUpdate: @Sendable (Components.Schemas.GetCandlesResponse) async -> Void
    private let onSubscribed: @Sendable () async -> Void
    private let onReconnecting: @Sendable () async -> Void
    private let onRejected: @Sendable () async -> Void

    private var pendingFeeds: Set<String> = []
    private var requests: [Int64: String] = [:]
    private var subscribed = false
    private var bufferedUpdates: [Components.Schemas.GetCandlesResponse] = []
    private var attempt = 0
    private var retryDelay = Session.minRetryDelay
    private var retryTask: Task<Void, Never>?
    private var cancelled = false

    init(
        hub: HermesSocketHub,
        feedId: String,
        volumeFeedId: String,
        sleep: @escaping @Sendable (TimeInterval) async -> Void,
        onUpdate: @escaping @Sendable (Components.Schemas.GetCandlesResponse) async -> Void,
        onVolumeUpdate: @escaping @Sendable (Components.Schemas.GetCandlesResponse) async -> Void,
        onSubscribed: @escaping @Sendable () async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) {
        self.hub = hub
        self.feedId = feedId
        self.volumeFeedId = volumeFeedId
        self.sleep = sleep
        self.onUpdate = onUpdate
        self.onVolumeUpdate = onVolumeUpdate
        self.onSubscribed = onSubscribed
        self.onReconnecting = onReconnecting
        self.onRejected = onRejected
    }

    func start() {
        guard !cancelled else { return }
        let listener = HermesSocketListener(
            onConnected: { await self.connected() },
            onFrame: { await self.receive($0) },
            onDisconnected: { await self.disconnected() }
        )
        if hub.attach(id, listener) {
            connected()
        }
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        retryTask?.cancel()
        for feed in [feedId, volumeFeedId] {
            hub.unsubscribe(feed, by: id) {
                try HermesRequest.encode(
                    channel: HermesChannel.unsubscribe,
                    name: HermesMessageName.unsubscribe,
                    reqid: $0,
                    payload: ["feedId": feed]
                )
            }
        }
        hub.detach(id)
    }

    private func connected() {
        guard !cancelled else { return }
        pendingFeeds = [feedId, volumeFeedId]
        requests = [:]
        subscribed = false
        bufferedUpdates = []
        retryDelay = Self.minRetryDelay
        subscribePending()
    }

    private func disconnected() async {
        guard !cancelled else { return }
        settle()
        pendingFeeds = []
        requests = [:]
        await onReconnecting()
    }

    private func subscribePending() {
        for feed in pendingFeeds {
            let requestId = hub.subscribe(feed, by: id) {
                try HermesRequest.encode(
                    channel: HermesChannel.subscribe,
                    name: HermesMessageName.subscribe,
                    reqid: $0,
                    payload: ["feedId": feed]
                )
            }
            if let requestId {
                requests[requestId] = feed
            }
        }
        resubscribe(after: Self.subscribeTimeout + nextRetryDelay())
    }

    private func nextRetryDelay() -> TimeInterval {
        defer { retryDelay = min(retryDelay * 2, Self.maxRetryDelay) }
        return retryDelay
    }

    private func resubscribe(after delay: TimeInterval) {
        attempt += 1
        let scheduled = attempt
        retryTask?.cancel()
        retryTask = Task { [weak self, sleep] in
            await sleep(delay)
            guard !Task.isCancelled else { return }
            await self?.resubscribe(attempt: scheduled)
        }
    }

    private func resubscribe(attempt scheduled: Int) {
        guard !cancelled, scheduled == attempt, !pendingFeeds.isEmpty else { return }
        subscribePending()
    }

    private func settle() {
        attempt += 1
        retryTask?.cancel()
        retryDelay = Self.minRetryDelay
    }

    private func receive(_ data: Data) async {
        guard !cancelled else { return }
        switch HermesCandleCodec.event(from: data) {
        case let .candles(pushFeedId, response):
            if pushFeedId == volumeFeedId {
                await onVolumeUpdate(response)
            } else if pushFeedId != feedId {
                return
            } else if subscribed {
                await onUpdate(response)
            } else {
                bufferedUpdates.append(response)
            }
        case let .subscribed(requestId):
            guard let feed = takeRequest(requestId) else { return }
            hub.markHealthy()
            pendingFeeds.remove(feed)
            if pendingFeeds.isEmpty {
                settle()
            }
            guard feed == feedId, !subscribed else { return }
            subscribed = true
            let buffered = bufferedUpdates
            bufferedUpdates = []
            await onSubscribed()
            for response in buffered {
                await onUpdate(response)
            }
        case let .retryableFailure(requestId):
            guard takeRequest(requestId) != nil else { return }
            resubscribe(after: nextRetryDelay())
        case let .rejected(requestId):
            guard let feed = takeRequest(requestId) else { return }
            pendingFeeds.remove(feed)
            if feed == feedId {
                await onRejected()
                cancel()
            } else if pendingFeeds.isEmpty {
                settle()
            }
        case .ignored:
            return
        }
    }

    private func takeRequest(_ requestId: Int64?) -> String? {
        requestId.flatMap { requests.removeValue(forKey: $0) }
    }

    private static let subscribeTimeout: TimeInterval = 30
    private static let minRetryDelay: TimeInterval = 1
    private static let maxRetryDelay: TimeInterval = 30
}
