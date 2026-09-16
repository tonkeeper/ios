import Foundation
import KeeperCore
import SwiftUI
import TKLocalize

@MainActor
final class PerpsSearchViewModel: ObservableObject {
    private enum Constants {
        static let searchDebounceNanoseconds: UInt64 = 300_000_000
    }

    enum MarketsState {
        case loading
        case loaded(items: [PerpsMarketRowItem], isLoadingNextPage: Bool)
        case empty
        case failed(String)
    }

    @Published private(set) var searchText = ""
    @Published private(set) var sort: PerpsMarketsSort = .volume
    @Published private(set) var marketsState: MarketsState = .loading

    var onBack: (() -> Void)?
    var onSelectMarket: ((Int64) -> Void)?

    private let repository: PerpsMarketsSearching
    private let marketsStore: PerpsMarketsStore
    private let priceInterest: PerpsMarketsPriceInterest
    private let debounceNanoseconds: UInt64

    private var searchTask: Task<Void, Never>?
    private var nextPageTask: Task<Void, Never>?
    private var searchGeneration = 0
    private var markets: [PerpsMarketSummary] = []
    private var nextCursor: String?
    private var visibleMarketIds: Set<Int64> = []

    init(
        repository: PerpsMarketsSearching,
        marketsStore: PerpsMarketsStore,
        debounceNanoseconds: UInt64 = Constants.searchDebounceNanoseconds
    ) {
        self.repository = repository
        self.marketsStore = marketsStore
        self.debounceNanoseconds = debounceNanoseconds
        priceInterest = marketsStore.makePriceInterest()
        marketsStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.applyLivePrices() }
        }
    }

    func onAppear() {
        load(debounced: false)
    }

    func onDisappear() {
        cancelRequests()
        priceInterest.clear()
    }

    func updateSearchText(_ value: String) {
        guard searchText != value else { return }
        searchText = value
        load(debounced: true)
    }

    func setSort(_ sort: PerpsMarketsSort) {
        guard sort != self.sort else { return }
        self.sort = sort
        load(debounced: false)
    }

    func selectMarket(_ id: Int64) {
        onSelectMarket?(id)
    }

    func rowAppeared(_ id: Int64) {
        if id == markets.last?.marketId {
            loadNextPage()
        }
        guard visibleMarketIds.insert(id).inserted else { return }
        priceInterest.set(marketIds: visibleMarketIds)
    }

    func rowDisappeared(_ id: Int64) {
        guard visibleMarketIds.remove(id) != nil else { return }
        priceInterest.set(marketIds: visibleMarketIds)
    }

    func retry() {
        load(debounced: false)
    }
}

private extension PerpsSearchViewModel {
    var normalizedQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func cancelRequests() {
        searchTask?.cancel()
        searchTask = nil
        nextPageTask?.cancel()
        nextPageTask = nil
    }

    func load(debounced: Bool) {
        cancelRequests()
        if case let .loaded(items, true) = marketsState {
            marketsState = .loaded(items: items, isLoadingNextPage: false)
        }
        searchGeneration += 1
        let generation = searchGeneration
        let query = normalizedQuery
        let sort = sort
        if case .loaded = marketsState {} else {
            marketsState = .loading
        }

        let delay = debounced ? debounceNanoseconds : 0
        searchTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.performSearch(generation: generation, query: query, sort: sort)
        }
    }

    func performSearch(generation: Int, query: String?, sort: PerpsMarketsSort) async {
        do {
            let page = try await repository.markets(query: query, sort: sort, cursor: nil)
            guard !Task.isCancelled, generation == searchGeneration else { return }
            searchTask = nil
            markets = page.items
            nextCursor = page.nextCursor
            if markets.isEmpty {
                marketsState = .empty
            } else {
                publishLoaded(isLoadingNextPage: false)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == searchGeneration else { return }
            searchTask = nil
            marketsState = .failed(TKLocales.Perps.Search.error)
        }
    }

    func loadNextPage() {
        guard searchTask == nil, nextPageTask == nil,
              case .loaded = marketsState,
              let cursor = nextCursor
        else { return }
        let generation = searchGeneration
        let query = normalizedQuery
        let sort = sort
        let repository = repository
        publishLoaded(isLoadingNextPage: true)
        nextPageTask = Task { [weak self] in
            let result: Result<PerpsMarketsPage, Error>
            do {
                result = try .success(await repository.markets(query: query, sort: sort, cursor: cursor))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled else { return }
            self?.completeNextPage(result, generation: generation)
        }
    }

    func completeNextPage(_ result: Result<PerpsMarketsPage, Error>, generation: Int) {
        nextPageTask = nil
        guard generation == searchGeneration, case .loaded = marketsState else { return }
        if case let .success(page) = result {
            let knownIds = Set(markets.map(\.marketId))
            markets += page.items.filter { !knownIds.contains($0.marketId) }
            nextCursor = page.nextCursor
        }
        publishLoaded(isLoadingNextPage: false)
    }

    func applyLivePrices() {
        guard case let .loaded(_, isLoadingNextPage) = marketsState else { return }
        publishLoaded(isLoadingNextPage: isLoadingNextPage)
    }

    func publishLoaded(isLoadingNextPage: Bool) {
        let state = marketsStore.getState()
        let items = markets.map { market in
            PerpsMarketRowMapping.item(from: market.overlayingLivePrice(state.price(marketId: market.marketId)))
        }
        if case let .loaded(current, currentIsLoading) = marketsState,
           current == items, currentIsLoading == isLoadingNextPage
        {
            return
        }
        marketsState = .loaded(items: items, isLoadingNextPage: isLoadingNextPage)
    }
}
