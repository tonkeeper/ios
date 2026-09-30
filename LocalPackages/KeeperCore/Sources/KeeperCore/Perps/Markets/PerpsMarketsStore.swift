import Foundation
import TKLogging

public final class PerpsMarketsPriceInterest {
    fileprivate let id = UUID()
    private let store: PerpsMarketsStore

    init(store: PerpsMarketsStore) {
        self.store = store
    }

    deinit {
        store.setPriceInterest([], id: id)
    }

    public func set(marketIds: Set<Int64>) {
        store.setPriceInterest(marketIds, id: id)
    }

    public func clear() {
        set(marketIds: [])
    }
}

public final class PerpsMarketsStore: Store<PerpsMarketsStore.Event, PerpsMarketsStore.State>, @unchecked Sendable {
    public struct Markets: Equatable, Sendable {
        public let sort: PerpsMarketsSort
        public let items: [PerpsMarketSummary]
        public let livePrices: [Int64: Double]
        public let hasNextPage: Bool
        public let isLoadingNextPage: Bool

        public init(
            sort: PerpsMarketsSort,
            items: [PerpsMarketSummary],
            livePrices: [Int64: Double],
            hasNextPage: Bool,
            isLoadingNextPage: Bool
        ) {
            self.sort = sort
            self.items = items
            self.livePrices = livePrices
            self.hasNextPage = hasNextPage
            self.isLoadingNextPage = isLoadingNextPage
        }

        public func livePrice(marketId: Int64) -> Double? {
            livePrices[marketId]
        }

        public func price(marketId: Int64) -> Double? {
            if let livePrice = livePrices[marketId] {
                return livePrice
            }
            guard let item = items.first(where: { $0.marketId == marketId }), item.hasPrice else { return nil }
            return item.price
        }
    }

    public enum State {
        case idle
        case loading
        case loaded(Markets)
        case failed

        public func livePrice(marketId: Int64) -> Double? {
            guard case let .loaded(markets) = self else { return nil }
            return markets.livePrice(marketId: marketId)
        }

        public func price(marketId: Int64) -> Double? {
            guard case let .loaded(markets) = self else { return nil }
            return markets.price(marketId: marketId)
        }
    }

    public enum Event {
        case didUpdate(State)
    }

    private let controller: PerpsMarketsController
    private let commandContinuation: AsyncStream<PerpsMarketsCommand>.Continuation
    private var commandTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?

    init(
        repository: PerpsMarketsReading,
        pricesClient: HermesMarkPricesStreaming,
        priceDebounceInterval: TimeInterval = 0.15,
        rejectedWatchRetryInterval: TimeInterval = 10
    ) {
        let (states, stateContinuation) = AsyncStream.makeStream(
            of: State.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let controller = PerpsMarketsController(
            repository: repository,
            pricesClient: pricesClient,
            stateContinuation: stateContinuation,
            priceDebounceInterval: priceDebounceInterval,
            rejectedWatchRetryInterval: rejectedWatchRetryInterval
        )
        let (commands, commandContinuation) = AsyncStream.makeStream(of: PerpsMarketsCommand.self)
        self.controller = controller
        self.commandContinuation = commandContinuation
        super.init(state: .idle)
        commandTask = Task {
            for await command in commands {
                await controller.handle(command)
            }
        }
        stateTask = Task { [weak self] in
            for await state in states {
                self?.publish(state)
            }
        }
    }

    deinit {
        commandContinuation.finish()
        commandTask?.cancel()
        stateTask?.cancel()
    }

    override public func createInitialState() -> State {
        .idle
    }

    public func subscribe() {
        commandContinuation.yield(.subscribe)
    }

    public func unsubscribe() {
        commandContinuation.yield(.unsubscribe)
    }

    public func setSort(_ sort: PerpsMarketsSort) {
        commandContinuation.yield(.setSort(sort))
    }

    public func loadNextPage() {
        commandContinuation.yield(.loadNextPage)
    }

    public func makePriceInterest() -> PerpsMarketsPriceInterest {
        PerpsMarketsPriceInterest(store: self)
    }

    public func price(marketId: Int64) async -> Double? {
        await controller.price(marketId: marketId)
    }

    public func livePrice(marketId: Int64) async -> Double? {
        await controller.livePrice(marketId: marketId)
    }

    public func snapshot(marketId: Int64) async -> PerpsAssetMarketSnapshot? {
        await controller.snapshot(marketId: marketId)
    }

    fileprivate func setPriceInterest(_ marketIds: Set<Int64>, id: UUID) {
        commandContinuation.yield(.setPriceInterest(id: id, marketIds: marketIds))
    }

    fileprivate func publish(_ state: State) {
        setStateNotifying(state, event: Event.didUpdate)
    }
}

private enum PerpsMarketsCommand: Sendable {
    case subscribe
    case unsubscribe
    case setSort(PerpsMarketsSort)
    case loadNextPage
    case setPriceInterest(id: UUID, marketIds: Set<Int64>)
}

private actor PerpsMarketsController {
    private enum Phase {
        case idle
        case loading
        case loaded
        case failed
    }

    private struct PriceWatch {
        let id: UUID
        let handle: HermesMarkPricesWatch
        let generation: Int
        var marketIdsByTicker: [String: Set<Int64>]
        var tickers: [String]
    }

    private let repository: PerpsMarketsReading
    private let pricesClient: HermesMarkPricesStreaming
    private let stateContinuation: AsyncStream<PerpsMarketsStore.State>.Continuation
    private let priceDebounceInterval: TimeInterval
    private let rejectedWatchRetryInterval: TimeInterval

    private var phase = Phase.idle
    private var sort = PerpsMarketsSort.volume
    private var items: [PerpsMarketSummary] = []
    private var itemIndexById: [Int64: Int] = [:]
    private var nextCursor: String?
    private var loadedPageCount = 0

    private var subscriberCount = 0
    private var loadGeneration = 0
    private var loadTask: Task<Void, Never>?
    private var nextPageTask: Task<Void, Never>?
    private var isLoadingNextPage = false

    private var priceInterests: [UUID: Set<Int64>] = [:]
    private var priceWatch: PriceWatch?
    private var priceApplyTask: Task<Void, Never>?
    private var priceGeneration = 0
    private var livePrices: [Int64: Double] = [:]
    private var livePriceRevisions: [Int64: Int] = [:]
    private var livePriceRevision = 0

    init(
        repository: PerpsMarketsReading,
        pricesClient: HermesMarkPricesStreaming,
        stateContinuation: AsyncStream<PerpsMarketsStore.State>.Continuation,
        priceDebounceInterval: TimeInterval,
        rejectedWatchRetryInterval: TimeInterval
    ) {
        self.repository = repository
        self.pricesClient = pricesClient
        self.stateContinuation = stateContinuation
        self.priceDebounceInterval = priceDebounceInterval
        self.rejectedWatchRetryInterval = rejectedWatchRetryInterval
    }

    deinit {
        stateContinuation.finish()
        loadTask?.cancel()
        nextPageTask?.cancel()
        priceApplyTask?.cancel()
        priceWatch?.handle.cancel()
    }

    func handle(_ command: PerpsMarketsCommand) {
        switch command {
        case .subscribe:
            subscribe()
        case .unsubscribe:
            unsubscribe()
        case let .setSort(sort):
            setSort(sort)
        case .loadNextPage:
            loadNextPage()
        case let .setPriceInterest(id, marketIds):
            setPriceInterest(marketIds, id: id)
        }
    }

    func price(marketId: Int64) -> Double? {
        if let livePrice = livePrices[marketId] {
            return livePrice
        }
        guard let index = itemIndexById[marketId], items[index].hasPrice else { return nil }
        return items[index].price
    }

    func livePrice(marketId: Int64) -> Double? {
        livePrices[marketId]
    }

    func snapshot(marketId: Int64) async -> PerpsAssetMarketSnapshot? {
        guard let details = try? await repository.marketDetails(marketId: marketId) else { return nil }
        return PerpsAssetMarketSnapshot(details: details).overlayingLivePrice(livePrices[marketId])
    }
}

private extension PerpsMarketsController {
    func subscribe() {
        subscriberCount += 1
        guard loadTask == nil else { return }
        reload(showLoading: phase != .loaded)
    }

    func unsubscribe() {
        subscriberCount = max(0, subscriberCount - 1)
    }

    var hasMarketDataInterest: Bool {
        subscriberCount > 0 || !priceInterestUnion.isEmpty
    }

    func loadMarketDataIfMissing() {
        guard hasMarketDataInterest, loadTask == nil, phase != .loaded else { return }
        reload(showLoading: true)
    }

    func setSort(_ newSort: PerpsMarketsSort) {
        guard newSort != sort else { return }
        sort = newSort
        nextCursor = nil
        loadedPageCount = 0
        cancelNextPageLoad()
        phase = .idle
        guard hasMarketDataInterest else {
            loadGeneration += 1
            loadTask?.cancel()
            loadTask = nil
            publish()
            return
        }
        reload(showLoading: true)
    }

    func reload(showLoading: Bool) {
        guard hasMarketDataInterest else { return }
        if showLoading {
            phase = .loading
            publish()
        }
        loadGeneration += 1
        let generation = loadGeneration
        let livePriceRevision = livePriceRevision
        let sort = sort
        let wasLoadingNextPage = nextPageTask != nil
        let pageCount = max(1, loadedPageCount + (wasLoadingNextPage ? 1 : 0))
        cancelNextPageLoad()
        if wasLoadingNextPage, !showLoading {
            publish()
        }
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            do {
                var pages: [PerpsMarketsPage] = []
                var cursor: String?
                repeat {
                    let page = try await repository.markets(query: nil, sort: sort, cursor: cursor)
                    guard !Task.isCancelled else { return }
                    pages.append(page)
                    cursor = page.nextCursor
                } while cursor != nil && pages.count < pageCount
                await self?.completeLoad(
                    .success(pages),
                    generation: generation,
                    livePriceRevision: livePriceRevision
                )
            } catch {
                guard !Task.isCancelled else { return }
                await self?.completeLoad(
                    .failure(error),
                    generation: generation,
                    livePriceRevision: livePriceRevision
                )
            }
        }
    }

    func completeLoad(
        _ result: Result<[PerpsMarketsPage], Error>,
        generation: Int,
        livePriceRevision: Int
    ) {
        guard generation == loadGeneration else { return }
        loadTask = nil
        switch result {
        case let .success(pages):
            phase = .loaded
            items = []
            itemIndexById = [:]
            appendItems(pages.flatMap(\.items))
            nextCursor = pages.last?.nextCursor
            loadedPageCount = pages.count
            discardLivePrices(through: livePriceRevision)
            publish()
        case let .failure(error):
            if phase != .loaded {
                phase = .failed
                publish()
            }
            Log.w("🪵 Perps: markets load failed — \(error)")
        }
    }

    func loadNextPage() {
        guard phase == .loaded, let cursor = nextCursor, nextPageTask == nil, loadTask == nil else { return }
        let generation = loadGeneration
        let sort = sort
        isLoadingNextPage = true
        publish()
        nextPageTask = Task { [weak self, repository] in
            let result: Result<PerpsMarketsPage, Error>
            do {
                result = try .success(await repository.markets(query: nil, sort: sort, cursor: cursor))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled else { return }
            await self?.completeNextPage(result, generation: generation)
        }
    }

    func completeNextPage(_ result: Result<PerpsMarketsPage, Error>, generation: Int) {
        guard generation == loadGeneration else { return }
        nextPageTask = nil
        isLoadingNextPage = false
        switch result {
        case let .success(page):
            appendItems(page.items)
            nextCursor = page.nextCursor
            loadedPageCount += 1
        case let .failure(error):
            Log.w("🪵 Perps: markets page load failed — \(error)")
        }
        publish()
    }

    func cancelNextPageLoad() {
        nextPageTask?.cancel()
        nextPageTask = nil
        isLoadingNextPage = false
    }

    func appendItems(_ newItems: [PerpsMarketSummary]) {
        var duplicateMarketIds: Set<Int64> = []
        for item in newItems {
            guard itemIndexById[item.marketId] == nil else {
                duplicateMarketIds.insert(item.marketId)
                continue
            }
            itemIndexById[item.marketId] = items.count
            items.append(item)
        }
        if !duplicateMarketIds.isEmpty {
            Log.w("🪵 Perps: ignored duplicate market ids — \(duplicateMarketIds.sorted())")
        }
    }
}

private extension PerpsMarketsController {
    func setPriceInterest(_ marketIds: Set<Int64>, id: UUID) {
        let hadMarketDataInterest = hasMarketDataInterest
        let previousUnion = priceInterestUnion
        if marketIds.isEmpty {
            priceInterests.removeValue(forKey: id)
        } else {
            priceInterests[id] = marketIds
        }
        let currentUnion = priceInterestUnion
        if !hadMarketDataInterest, hasMarketDataInterest {
            loadMarketDataIfMissing()
        }
        let needsWatch = !currentUnion.isEmpty && priceWatch == nil && priceApplyTask == nil
        guard currentUnion != previousUnion || needsWatch else { return }
        if currentUnion.isEmpty {
            priceGeneration += 1
            priceApplyTask?.cancel()
            let watch = priceWatch?.handle
            priceWatch = nil
            priceApplyTask = nil
            watch?.cancel()
            publish()
            return
        }

        schedulePriceInterestUpdate()
        publish()
    }

    func schedulePriceInterestUpdate() {
        priceGeneration += 1
        priceApplyTask?.cancel()
        let generation = priceGeneration
        priceApplyTask = Task { [weak self, priceDebounceInterval] in
            if priceDebounceInterval > 0 {
                try? await Task.sleep(nanoseconds: UInt64(priceDebounceInterval * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await self?.applyPriceInterests(generation: generation)
        }
    }

    var priceInterestUnion: Set<Int64> {
        priceInterests.values.reduce(into: Set<Int64>()) { $0.formUnion($1) }
    }

    func applyPriceInterests(generation: Int) async {
        guard generation == priceGeneration else { return }
        let marketIds = priceInterestUnion
        guard !marketIds.isEmpty else { return }

        let tickersByMarketId: [Int64: String]
        do {
            tickersByMarketId = try await repository.tickers(for: marketIds)
        } catch {
            guard generation == priceGeneration else { return }
            Log.w("🪵 Perps: live prices metadata lookup failed — \(error)")
            schedulePriceRetry(generation: generation, after: Self.metadataRetryInterval)
            return
        }
        guard generation == priceGeneration else { return }

        let missing = marketIds.count - tickersByMarketId.count
        if missing > 0 {
            Log.w("🪵 Perps: live prices skip \(missing) markets without tickers")
        }
        let marketIdsByTicker = marketIdsByTicker(tickersByMarketId)
        let tickers = marketIdsByTicker.keys.sorted()
        guard !tickers.isEmpty else {
            let watch = priceWatch?.handle
            priceWatch = nil
            priceApplyTask = nil
            watch?.cancel()
            publish()
            return
        }

        if var watch = priceWatch {
            watch.marketIdsByTicker = marketIdsByTicker
            watch.tickers = tickers
            priceWatch = PriceWatch(
                id: watch.id,
                handle: watch.handle,
                generation: generation,
                marketIdsByTicker: watch.marketIdsByTicker,
                tickers: watch.tickers
            )
            priceApplyTask = nil
            watch.handle.setTickers(tickers)
            return
        }

        let id = UUID()
        let handle = makePriceWatch(id: id)
        priceWatch = PriceWatch(
            id: id,
            handle: handle,
            generation: generation,
            marketIdsByTicker: marketIdsByTicker,
            tickers: tickers
        )
        priceApplyTask = nil
        handle.setTickers(tickers)
    }

    func schedulePriceRetry(generation: Int, after interval: TimeInterval) {
        guard generation == priceGeneration, !priceInterestUnion.isEmpty else { return }
        priceApplyTask?.cancel()
        priceApplyTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.applyPriceInterests(generation: generation)
        }
    }

    static let metadataRetryInterval: TimeInterval = 5

    func makePriceWatch(id: UUID) -> HermesMarkPricesWatch {
        pricesClient.watch(
            onUpdate: { [weak self] snapshot in
                await self?.receivePrices(snapshot, watchId: id)
            },
            onReconnecting: { [weak self] in
                await self?.priceWatchReconnecting(id: id)
            },
            onRejected: { [weak self] in
                await self?.rejectPriceWatch(id: id)
            }
        )
    }

    func receivePrices(_ snapshot: HermesMarkPricesSnapshot, watchId: UUID) {
        guard let watch = priceWatch,
              watch.id == watchId,
              watch.generation == priceGeneration,
              watch.tickers == snapshot.tickers
        else { return }
        for entry in snapshot.prices {
            guard let marketIds = watch.marketIdsByTicker[entry.ticker],
                  let value = PerpsMarketMath.optionalDouble(entry.price),
                  value > 0
            else { continue }
            for marketId in marketIds {
                livePriceRevision += 1
                livePrices[marketId] = value
                livePriceRevisions[marketId] = livePriceRevision
            }
        }
        publish()
    }

    func priceWatchReconnecting(id: UUID) {
        guard priceWatch?.id == id else { return }
        clearLivePrices()
        publish()
    }

    func rejectPriceWatch(id: UUID) {
        guard priceWatch?.id == id else { return }
        priceWatch = nil
        priceGeneration += 1
        priceApplyTask?.cancel()
        priceApplyTask = nil
        clearLivePrices()
        Log.w("🪵 Perps: hermes prices subscription rejected")
        publish()
        schedulePriceRetry(generation: priceGeneration, after: rejectedWatchRetryInterval)
    }

    func clearLivePrices() {
        livePrices.removeAll()
        livePriceRevisions.removeAll()
    }

    func discardLivePrices(through revision: Int) {
        let marketIds = livePriceRevisions.compactMap { marketId, liveRevision in
            liveRevision <= revision ? marketId : nil
        }
        for marketId in marketIds {
            livePrices.removeValue(forKey: marketId)
            livePriceRevisions.removeValue(forKey: marketId)
        }
    }

    func marketIdsByTicker(_ tickersByMarketId: [Int64: String]) -> [String: Set<Int64>] {
        tickersByMarketId.reduce(into: [:]) { result, entry in
            result[entry.value, default: []].insert(entry.key)
        }
    }
}

private extension PerpsMarketsController {
    func publish() {
        let state: PerpsMarketsStore.State
        switch phase {
        case .idle:
            state = .idle
        case .loading:
            state = .loading
        case .loaded:
            state = .loaded(PerpsMarketsStore.Markets(
                sort: sort,
                items: items.map { $0.overlayingLivePrice(livePrices[$0.marketId]) },
                livePrices: livePrices,
                hasNextPage: nextCursor != nil,
                isLoadingNextPage: isLoadingNextPage
            ))
        case .failed:
            state = .failed
        }

        stateContinuation.yield(state)
    }
}
