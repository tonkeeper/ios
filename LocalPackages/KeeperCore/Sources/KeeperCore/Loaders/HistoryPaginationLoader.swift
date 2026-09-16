import Foundation
import TonSwift

public actor HistoryPaginationLoader {
    public enum Event: Sendable {
        case initialLoading
        case initialLoadingFailed
        case initialLoaded([HistoryEvent], hasMore: Bool)
        case pageLoading
        case pageLoadingFailed
        case pageLoaded([HistoryEvent], hasMore: Bool)
    }

    public nonisolated let events: AsyncStream<Event>

    public enum ReloadReason: Sendable {
        /// Initial load or a user-initiated refresh: starts right away.
        case immediate
        /// Throttled refresh with no follow-up: screen appearance, filter changes.
        case refresh
        /// A streaming update announced a transaction: throttled, then retried with bounded
        /// backoff because indexing lags a couple of seconds behind the notification.
        case streamingUpdate
    }

    private enum LoadKind: Sendable, Equatable {
        case reload
        case page
    }

    private enum DeferredReload {
        case afterCurrentLoad
        case scheduled(Task<Void, Never>)
    }

    private let eventContinuation: AsyncStream<Event>.Continuation
    private var currentLoad: (kind: LoadKind, task: Task<Void, Never>)?
    private var lastReloadDate: Date?
    private var deferredReload: DeferredReload?
    private var nextStreamingRetryAttempt: Int?
    private var pagination = HistoryListLoaderPagination(
        tonEventsBeforeLt: nil,
        tronEventsMaxTimestamp: nil,
        tonHasMore: true,
        tronHasMore: true
    )

    private let wallet: Wallet
    private let loader: HistoryListLoader
    private let nftService: NFTService
    private let minReloadInterval: TimeInterval
    private let sleep: Sleep
    private let now: @Sendable () -> Date

    typealias Sleep = @Sendable (_ delay: TimeInterval) async throws -> Void

    init(
        wallet: Wallet,
        loader: HistoryListLoader,
        nftService: NFTService,
        minReloadInterval: TimeInterval = HistoryPaginationLoader.defaultMinReloadInterval,
        sleep: @escaping Sleep = HistoryPaginationLoader.defaultSleep,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        (events, eventContinuation) = AsyncStream<Event>.makeStream()
        self.wallet = wallet
        self.loader = loader
        self.nftService = nftService
        self.minReloadInterval = minReloadInterval
        self.sleep = sleep
        self.now = now
    }

    /// Reloads the first page.
    ///
    /// Only `.immediate` restarts a load right away. Everything else is throttled to one request
    /// per `minReloadInterval` and coalesced while a reload is in flight: a batched transfer
    /// arrives as dozens of streaming updates within a few seconds, and restarting the same request
    /// on each of them only aborts it before the backend answers.
    public func reload(reason: ReloadReason) {
        switch reason {
        case .immediate:
            if case let .scheduled(task) = deferredReload {
                task.cancel()
            }
            deferredReload = nil
            startReload()
        case .refresh:
            scheduleReload()
        case .streamingUpdate:
            nextStreamingRetryAttempt = 0
            guard currentLoad?.kind != .reload else { return }
            scheduleReload()
        }
    }

    private func scheduleReload(minimumDelay: TimeInterval = 0) {
        let isReloadInFlight = currentLoad?.kind == .reload

        switch Self.reloadDecision(
            isReloadInFlight: isReloadInFlight,
            isReloadScheduled: isReloadScheduled,
            lastReloadDate: lastReloadDate,
            now: now(),
            minInterval: minReloadInterval,
            minimumDelay: minimumDelay
        ) {
        case .start:
            startReload()
        case .coalesce:
            deferredReload = .afterCurrentLoad
        case .skip:
            break
        case let .schedule(delay):
            let sleep = sleep
            let task = Task { [weak self] in
                do {
                    try await sleep(delay)
                    try Task.checkCancellation()
                    await self?.runScheduledReload()
                } catch {
                    return
                }
            }
            deferredReload = .scheduled(task)
        }
    }

    private var isReloadScheduled: Bool {
        guard case .scheduled = deferredReload else { return false }
        return true
    }

    private func runScheduledReload() {
        guard !Task.isCancelled else { return }
        deferredReload = nil
        scheduleReload()
    }

    private func startReload() {
        let pagination = HistoryListLoaderPagination(
            tonEventsBeforeLt: nil,
            tronEventsMaxTimestamp: nil,
            tonHasMore: true,
            tronHasMore: true
        )
        lastReloadDate = now()
        startLoad(kind: .reload, pagination: pagination)
    }

    public func loadNext() {
        guard currentLoad == nil, pagination.hasMore else { return }
        startLoad(kind: .page, pagination: pagination)
    }

    private func startLoad(kind: LoadKind, pagination: HistoryListLoaderPagination) {
        currentLoad?.task.cancel()
        switch kind {
        case .reload:
            eventContinuation.yield(.initialLoading)
        case .page:
            eventContinuation.yield(.pageLoading)
        }
        // The actor intentionally stays alive until the operation commits or observes cancellation.
        let task: Task<Void, Never> = Task { [self] in
            await performLoad(kind: kind, pagination: pagination)
        }
        currentLoad = (kind: kind, task: task)
    }

    private func performLoad(kind: LoadKind, pagination: HistoryListLoaderPagination) async {
        do {
            let batch = try await loadNextPage(pagination: pagination)
            try Task.checkCancellation()

            let nextPagination = Self.makeNextPagination(previous: pagination, batch: batch)
            self.pagination = nextPagination
            let historyEvents = handleLoadedBatch(batch: batch)
            switch kind {
            case .reload:
                eventContinuation.yield(.initialLoaded(historyEvents, hasMore: nextPagination.hasMore))
            case .page:
                eventContinuation.yield(.pageLoaded(historyEvents, hasMore: nextPagination.hasMore))
            }
        } catch {
            guard !Task.isCancelled else { return }
            if !error.isCancelledError {
                switch kind {
                case .reload:
                    eventContinuation.yield(.initialLoadingFailed)
                case .page:
                    eventContinuation.yield(.pageLoadingFailed)
                }
            }
        }
        switch kind {
        case .reload:
            finishReload()
        case .page:
            currentLoad = nil
        }
    }

    private func finishReload() {
        currentLoad = nil

        if case .afterCurrentLoad = deferredReload {
            deferredReload = nil
            scheduleReload()
            return
        }

        // Account events do not expose the streaming transaction hash or lt, so there is no safe
        // early-success check. A small fixed retry budget is predictable and avoids leaving the
        // list stale when another event changes the history head first.
        guard let attempt = nextStreamingRetryAttempt,
              attempt < .maxReloadRetryAttempts
        else {
            nextStreamingRetryAttempt = nil
            return
        }
        nextStreamingRetryAttempt = attempt + 1
        let delay = minReloadInterval * TimeInterval(1 << attempt)
        scheduleReload(minimumDelay: delay)
    }

    func loadNextPage(pagination: HistoryListLoaderPagination) async throws -> HistoryEventsBatch {
        let events = try await loader.loadEvents(
            wallet: wallet,
            pagination: pagination,
            limit: .limit
        )
        try Task.checkCancellation()
        await handleEventsWithNFTs(events: events.accountsEvents?.events ?? [])
        return events
    }

    func handleEventsWithNFTs(events: [AccountEvent]) async {
        let actions = events.flatMap { $0.actions }
        var nftAddressesToLoad = Set<Address>()
        for action in actions {
            switch action.type {
            case let .nftItemTransfer(nftItemTransfer):
                nftAddressesToLoad.insert(nftItemTransfer.nftAddress)
            case let .nftPurchase(nftPurchase):
                try? nftService.saveNFT(nft: nftPurchase.nft, network: wallet.network)
            default: continue
            }
        }
        guard !nftAddressesToLoad.isEmpty else { return }
        _ = try? await nftService.loadNFTs(addresses: Array(nftAddressesToLoad), network: wallet.network)
    }

    private static func makeNextPagination(
        previous: HistoryListLoaderPagination,
        batch: HistoryEventsBatch
    ) -> HistoryListLoaderPagination {
        let tonFailed = batch.accountsEvents == nil
        let tronFailed = batch.tronTransactions == nil

        let tonHasMore: Bool
        if tonFailed {
            tonHasMore = true
        } else if let nextFrom = batch.accountsEvents?.nextFrom {
            tonHasMore = nextFrom != 0
        } else {
            tonHasMore = false
        }

        let tronHasMore: Bool
        if tronFailed {
            tronHasMore = false
        } else {
            tronHasMore = (batch.tronTransactions?.count ?? 0) >= .limit
        }

        return HistoryListLoaderPagination(
            tonEventsBeforeLt: tonFailed ? previous.tonEventsBeforeLt : batch.accountsEvents?.nextFrom,
            tronEventsMaxTimestamp: tronFailed
                ? previous.tronEventsMaxTimestamp
                : (batch.tronTransactions?.last?.timestamp ?? previous.tronEventsMaxTimestamp),
            tonHasMore: tonHasMore,
            tronHasMore: tronHasMore
        )
    }

    func handleLoadedBatch(batch: HistoryEventsBatch) -> [HistoryEvent] {
        let tonHistoryEvents = (batch.accountsEvents?.events ?? []).map { HistoryEvent.tonAccountEvent($0) }
        let tronHistoryEvents = (batch.tronTransactions ?? []).map { HistoryEvent.tronEvent($0) }
        let events = tonHistoryEvents + tronHistoryEvents
        return events.sorted(by: { $0.timestamp > $1.timestamp })
    }
}

private extension Int {
    static let limit: Int = 20
    static let maxReloadRetryAttempts: Int = 3
}

extension HistoryPaginationLoader {
    static let defaultMinReloadInterval: TimeInterval = 1

    static let defaultSleep: Sleep = { delay in
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    enum ReloadDecision: Equatable {
        case start
        /// A reload is already in flight: remember the trigger and reload once it finishes.
        case coalesce
        case schedule(after: TimeInterval)
        /// A deferred reload is already scheduled and will pick this trigger up.
        case skip
    }

    static func reloadDecision(
        isReloadInFlight: Bool,
        isReloadScheduled: Bool,
        lastReloadDate: Date?,
        now: Date,
        minInterval: TimeInterval,
        minimumDelay: TimeInterval = 0
    ) -> ReloadDecision {
        guard !isReloadInFlight else { return .coalesce }
        guard !isReloadScheduled else { return .skip }
        let throttleRemaining = lastReloadDate.map { minInterval - now.timeIntervalSince($0) } ?? 0
        let delay = max(throttleRemaining, minimumDelay)
        return delay > 0 ? .schedule(after: delay) : .start
    }
}
