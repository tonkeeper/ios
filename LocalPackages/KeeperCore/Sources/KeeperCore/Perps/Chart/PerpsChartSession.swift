import Foundation
import TKKandelabrAPI

actor PerpsChartSession {
    private enum Phase: Equatable {
        case idle
        case loadingInitialHistory(subscriptionCount: Int)
        case ready
        case finished
    }

    private enum Termination {
        case cancelled
        case failed
    }

    private struct Refresh {
        let id: Int
        let task: Task<Void, Never>
        var protectedTimestamps: Set<Int64>
    }

    private let marketId: Int64
    private let timeframe: PerpsChartTimeframe
    private let historySource: PerpsChartHistorySource
    private let hermes: HermesCandleStreaming
    private let marketsRepository: PerpsMarketsReading
    private let snapshotBars: Int32
    private let onUpdate: @Sendable (PerpsChartSnapshot) -> Void
    private let onReconnecting: @Sendable () -> Void
    private let onFailed: @Sendable () -> Void

    private var bootstrapTask: Task<Void, Never>?
    private var pagingTask: Task<Void, Never>?
    private var refresh: Refresh?
    private var liveWatch: HermesCandleWatch?
    private var liveFeedRejected = false
    private var phase = Phase.idle
    private var nextRefreshID = 0
    private var ticker: String?
    private var priceDecimals = PerpsChartService.defaultPriceDecimals
    private var timeline: PerpsChartTimeline

    init(
        marketId: Int64,
        timeframe: PerpsChartTimeframe,
        kandelabr: KandelabrAPI,
        hermes: HermesCandleStreaming,
        marketsRepository: PerpsMarketsReading,
        snapshotBars: Int32,
        onUpdate: @escaping @Sendable (PerpsChartSnapshot) -> Void,
        onReconnecting: @escaping @Sendable () -> Void,
        onFailed: @escaping @Sendable () -> Void
    ) {
        self.marketId = marketId
        self.timeframe = timeframe
        historySource = PerpsChartHistorySource(kandelabr: kandelabr, timeframe: timeframe)
        self.hermes = hermes
        self.marketsRepository = marketsRepository
        self.snapshotBars = snapshotBars
        self.onUpdate = onUpdate
        self.onReconnecting = onReconnecting
        self.onFailed = onFailed
        timeline = PerpsChartTimeline(timeframe: timeframe)
    }

    func start() {
        guard case .idle = phase else { return }
        phase = .loadingInitialHistory(subscriptionCount: 0)
        bootstrapTask = Task { await run() }
    }

    func cancel() {
        stop(.cancelled)
    }

    private func stop(_ termination: Termination) {
        guard phase != .finished else { return }
        phase = .finished
        let watch = liveWatch
        liveWatch = nil
        bootstrapTask?.cancel()
        bootstrapTask = nil
        pagingTask?.cancel()
        pagingTask = nil
        refresh?.task.cancel()
        refresh = nil
        watch?.cancel()
        if case .failed = termination {
            onFailed()
        }
    }

    func loadOlder(count: Int64, onLoaded: @escaping @Sendable (PerpsChartPage) -> Void) {
        switch phase {
        case .ready:
            break
        case .finished:
            onLoaded(.failed)
            return
        case .idle, .loadingInitialHistory:
            onLoaded(.busy)
            return
        }
        guard pagingTask == nil else {
            onLoaded(.busy)
            return
        }
        guard let ticker, let oldestTimestamp = timeline.oldestTimestamp else {
            onLoaded(.noMore)
            return
        }
        pagingTask = Task {
            let page = await fetchOlder(ticker: ticker, before: oldestTimestamp, count: count)
            pagingTask = nil
            guard case .ready = phase, !Task.isCancelled else { return }
            onLoaded(page)
        }
    }

    private func run() async {
        guard let market = await marketsRepository.market(marketId: marketId) else {
            if case .loadingInitialHistory = phase {
                stop(.failed)
            }
            return
        }
        guard case .loadingInitialHistory = phase else { return }

        ticker = market.ticker
        priceDecimals = market.priceDecimals
        let watch = hermes.watch(
            feedId: "\(market.ticker)/\(timeframe.resolution)",
            onUpdate: { [weak self] batch in
                await self?.receiveLive(batch)
            },
            onSubscribed: { [weak self] in
                await self?.didSubscribe()
            },
            onReconnecting: { [weak self] in
                await self?.forwardReconnecting()
            },
            onRejected: { [weak self] in
                await self?.rejectLiveFeed()
            }
        )
        liveWatch = watch

        let history = await historySource.latest(ticker: market.ticker, count: snapshotBars)
        guard case .loadingInitialHistory = phase, !Task.isCancelled else { return }
        finishInitialHistory(history)
    }

    private func forwardReconnecting() {
        guard phase != .finished else { return }
        onReconnecting()
    }

    private func didSubscribe() {
        switch phase {
        case let .loadingInitialHistory(subscriptionCount):
            phase = .loadingInitialHistory(subscriptionCount: subscriptionCount + 1)
        case .ready:
            scheduleRefresh()
        case .idle, .finished:
            break
        }
    }

    private func scheduleRefresh() {
        guard case .ready = phase, let ticker else { return }
        nextRefreshID += 1
        let id = nextRefreshID
        refresh?.task.cancel()
        let task = Task { [weak self] in
            _ = await self?.refreshHistory(ticker: ticker, id: id)
        }
        refresh = Refresh(id: id, task: task, protectedTimestamps: [])
    }

    private func rejectLiveFeed() {
        liveFeedRejected = true
        liveWatch?.cancel()
        liveWatch = nil
        guard case .ready = phase else { return }
        if timeline.isEmpty {
            stop(.failed)
        } else {
            publishSnapshot()
        }
    }

    private func finishInitialHistory(_ result: PerpsChartHistorySource.FetchResult) {
        guard case let .loadingInitialHistory(subscriptionCount) = phase else { return }
        switch result {
        case .rejected:
            stop(.failed)
        case .unavailable:
            if liveFeedRejected, timeline.isEmpty {
                stop(.failed)
                return
            }
            phase = .ready
            bootstrapTask = nil
            if !timeline.isEmpty {
                publishSnapshot()
            }
            if subscriptionCount > 0 {
                scheduleRefresh()
            }
        case let .response(history):
            guard let historyBatch = mappedBatch(history) else {
                stop(.failed)
                return
            }
            let liveTimestamps = timeline.candleTimestamps
            merge(historyBatch, preserving: liveTimestamps, publish: false)
            phase = .ready
            bootstrapTask = nil
            publishSnapshot()
            if subscriptionCount > 1 {
                scheduleRefresh()
            }
        }
    }

    private func refreshHistory(ticker: String, id: Int) async {
        let history = await historySource.latest(ticker: ticker, count: snapshotBars)
        guard case .ready = phase,
              !Task.isCancelled,
              let activeRefresh = refresh,
              activeRefresh.id == id
        else { return }
        refresh = nil
        if case let .response(history) = history, let historyBatch = mappedBatch(history) {
            merge(historyBatch, preserving: activeRefresh.protectedTimestamps)
        }
    }

    private func receiveLive(_ batch: TKKandelabrAPI.Components.Schemas.GetCandlesResponse) {
        guard let incoming = mappedBatch(batch) else { return }
        switch phase {
        case .loadingInitialHistory:
            merge(incoming, publish: false)
        case .ready:
            if var activeRefresh = refresh {
                activeRefresh.protectedTimestamps.formUnion(incoming.candleTimestamps)
                refresh = activeRefresh
            }
            merge(incoming)
        case .idle, .finished:
            break
        }
    }

    private func fetchOlder(ticker: String, before endTs: Int64, count: Int64) async -> PerpsChartPage {
        switch await historySource.older(ticker: ticker, before: endTs, count: count) {
        case .rejected:
            return .noMore
        case .unavailable:
            return .failed
        case let .response(batch):
            guard let incoming = mappedBatch(batch) else { return .noMore }
            return merge(incoming) ? .loaded : .noMore
        }
    }

    private func mappedBatch(
        _ batch: TKKandelabrAPI.Components.Schemas.GetCandlesResponse
    ) -> PerpsChartCandleMapper.Batch? {
        guard let ticker, PerpsChartCandleMapper.matchesFeed(batch, ticker: ticker, timeframe: timeframe) else {
            return nil
        }
        return PerpsChartCandleMapper.mapBatch(from: batch, timeframe: timeframe)
    }

    @discardableResult
    private func merge(
        _ incoming: PerpsChartCandleMapper.Batch,
        preserving protectedTimestamps: Set<Int64> = [],
        publish: Bool = true
    ) -> Bool {
        guard phase != .finished else { return false }
        let grew = timeline.merge(incoming, preserving: protectedTimestamps)
        if publish {
            publishSnapshot()
        }
        return grew
    }

    private func publishSnapshot() {
        onUpdate(PerpsChartSnapshot(
            marketId: marketId,
            timeframe: timeframe,
            candles: timeline.publishedCandles,
            priceDecimals: priceDecimals
        ))
    }
}
