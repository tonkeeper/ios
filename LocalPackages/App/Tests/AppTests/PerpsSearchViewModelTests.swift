@testable import App
import Combine
@testable import KeeperCore
@testable import Perps
import PerpsModels
import XCTest

final class PerpsSearchViewModelTests: XCTestCase {
    @MainActor
    func test_setFilter_preservesQueryAndSortAndResetsPagination() async {
        let repository = PerpsMarketsSearchingSpy()
        repository.setResults([makeMarket(id: 1, symbol: "BTC")], nextCursor: "next")
        let viewModel = makeViewModel(repository: repository)
        await expectPublished(viewModel.$marketsState, description: "initial", matching: { $0.loadedMarketIDs == [1] }) {
            viewModel.updateSearchText(" BTC ")
            viewModel.setSort(.openInterest)
        }
        repository.setResults([makeMarket(id: 2, symbol: "GOLD")], nextCursor: "commodities-next")
        await expectPublished(viewModel.$marketsState, description: "filtered", matching: { $0.loadedMarketIDs == [2] }) {
            viewModel.setFilter(.commodities)
        }
        XCTAssertEqual(viewModel.searchText, " BTC ")
        XCTAssertEqual(repository.requests.last, .init(query: "BTC", sort: .openInterest, cursor: nil, filter: .commodities))
        let count = repository.requests.count
        viewModel.setFilter(.commodities)
        XCTAssertEqual(repository.requests.count, count)

        repository.pages["commodities-next"] = PerpsMarketsPage(items: [makeMarket(id: 3, symbol: "SILVER")], nextCursor: nil)
        await expectPublished(viewModel.$marketsState, description: "next page", matching: { $0.loadedMarketIDs == [2, 3] }) {
            viewModel.rowAppeared(2)
        }
        XCTAssertEqual(repository.requests.last, .init(query: "BTC", sort: .openInterest, cursor: "commodities-next", filter: .commodities))
        viewModel.onDisappear()
    }

    @MainActor
    func test_setFilter_ignoresPreviousFiltersInFlightPage() async {
        let repository = PerpsMarketsSearchingSpy()
        let pageStarted = expectation(description: "previous filter pagination started")
        let pageFinished = expectation(description: "previous filter pagination completed")
        var continuation: CheckedContinuation<PerpsMarketsPage, Never>?
        repository.handler = { request in
            if request.cursor == "old-next" {
                let page = await withCheckedContinuation { pending in
                    continuation = pending
                    pageStarted.fulfill()
                }
                pageFinished.fulfill()
                return page
            }
            let id: Int64 = request.filter == .stocks ? 9 : 1
            return PerpsMarketsPage(items: [self.makeMarket(id: id, symbol: "BTC")], nextCursor: "old-next")
        }
        let viewModel = makeViewModel(repository: repository)
        await expectPublished(viewModel.$marketsState, description: "initial", matching: { $0.loadedMarketIDs == [1] }) {
            viewModel.onAppear()
        }
        viewModel.rowAppeared(1)
        await fulfillment(of: [pageStarted], timeout: 1)
        await expectPublished(viewModel.$marketsState, description: "stocks", matching: { $0.loadedMarketIDs == [9] }) {
            viewModel.setFilter(.stocks)
        }
        continuation?.resume(returning: PerpsMarketsPage(items: [makeMarket(id: 2, symbol: "ETH")], nextCursor: nil))
        await fulfillment(of: [pageFinished], timeout: 1)
        await Task.yield()
        XCTAssertEqual(viewModel.marketsState.loadedMarketIDs, [9])
        XCTAssertEqual(repository.requests.map(\.filter), [.all, .all, .stocks])
        viewModel.onDisappear()
    }

    @MainActor
    func test_onAppear_requestsVolumeSortWithoutQuery_andSelectsMarket() async {
        let repository = PerpsMarketsSearchingSpy()
        repository.setResults([
            makeMarket(id: 2, symbol: "ETH", volume: 20),
            makeMarket(id: 1, symbol: "BTC", volume: 10),
        ])
        let viewModel = makeViewModel(repository: repository)
        var selected: Int64?
        viewModel.onSelectMarket = { selected = $0 }

        await expectPublished(
            viewModel.$marketsState,
            description: "markets loaded",
            matching: { $0.loadedMarketIDs == [2, 1] }
        ) {
            viewModel.onAppear()
        }

        XCTAssertEqual(repository.requests, [.init(query: nil, sort: .volume, cursor: nil)])

        viewModel.selectMarket(2)
        XCTAssertEqual(selected, 2)
        viewModel.onDisappear()
    }

    @MainActor
    func test_updateSearchText_debouncesAndKeepsOnlyTheLatestQuery() async {
        let repository = PerpsMarketsSearchingSpy()
        repository.setResults([makeMarket(id: 1, symbol: "BTC")])
        let viewModel = makeViewModel(repository: repository)

        await expectPublished(
            viewModel.$marketsState,
            description: "initial load",
            matching: { $0.loadedMarketIDs == [1] }
        ) {
            viewModel.onAppear()
        }
        XCTAssertEqual(repository.requests.count, 1)

        repository.setResults([makeMarket(id: 7, symbol: "ETH")])
        viewModel.updateSearchText("e")
        guard case .loading = viewModel.marketsState else {
            return XCTFail("expected loading, got \(viewModel.marketsState)")
        }
        viewModel.updateSearchText("et")
        viewModel.updateSearchText("eth ")

        await expectPublished(
            viewModel.$marketsState,
            description: "debounced query",
            matching: { $0.loadedMarketIDs == [7] }
        ) {
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        XCTAssertEqual(repository.requests.map(\.query), [nil, "eth"])

        viewModel.updateSearchText(" eth")
        XCTAssertEqual(viewModel.marketsState.loadedMarketIDs, [7])
        viewModel.onDisappear()
    }

    @MainActor
    func test_setSort_requestsServerSortedResultsImmediately() async {
        let repository = PerpsMarketsSearchingSpy()
        repository.setResults([
            makeMarket(id: 2, symbol: "ETH", volume: 20),
            makeMarket(id: 1, symbol: "BTC", volume: 10),
        ])
        let viewModel = makeViewModel(repository: repository)

        await expectPublished(
            viewModel.$marketsState,
            description: "sorted by volume",
            matching: { $0.loadedMarketIDs == [2, 1] }
        ) {
            viewModel.onAppear()
        }

        repository.setResults([
            makeMarket(id: 1, symbol: "BTC", priceChange: 5),
            makeMarket(id: 2, symbol: "ETH", priceChange: 1),
        ])
        await expectPublished(
            viewModel.$marketsState,
            description: "sorted by price change",
            matching: { $0.loadedMarketIDs == [1, 2] }
        ) {
            viewModel.setSort(.priceChange)
        }

        XCTAssertEqual(repository.requests.last, .init(query: nil, sort: .priceChange, cursor: nil))
        XCTAssertEqual(repository.requests.count, 2)
        viewModel.onDisappear()
    }

    @MainActor
    func test_livePriceTick_patchesRowInPlaceWithoutReordering() async {
        let repository = PerpsMarketsSearchingSpy()
        repository.setResults([
            makeMarket(id: 1, symbol: "BTC", volume: 20, price: 100),
            makeMarket(id: 2, symbol: "ETH", volume: 10, price: 50),
        ])
        let client = FakeMarkPricesClient()
        let store = PerpsMarketsStore.makeForTests(
            tickers: [1: "BTC/USD", 2: "ETH/USD"],
            client: client
        )
        let viewModel = makeViewModel(repository: repository, store: store)

        await expectPublished(
            viewModel.$marketsState,
            description: "results loaded",
            matching: { $0.loadedMarketIDs == [1, 2] }
        ) {
            viewModel.onAppear()
        }

        viewModel.rowAppeared(1)
        viewModel.rowAppeared(2)
        await waitForTickers(client, toEqual: ["BTC/USD", "ETH/USD"])

        await expectPublished(
            viewModel.$marketsState,
            description: "price patched in place",
            matching: { state in
                state.loadedItems.first(where: { $0.id == 2 })?.priceText == PerpsFormatting.live.usd(60)
            }
        ) {
            await client.emit([("ETH/USD", "60")])
        }
        XCTAssertEqual(viewModel.marketsState.loadedMarketIDs, [1, 2])
        XCTAssertEqual(repository.requests.count, 1)
        viewModel.onDisappear()
    }

    @MainActor
    func test_subsequentError_replacesLoadedWithFailed() async {
        let repository = PerpsMarketsSearchingSpy()
        repository.setResults([makeMarket(id: 1, symbol: "BTC")])
        let viewModel = makeViewModel(repository: repository)

        await expectPublished(
            viewModel.$marketsState,
            description: "initial load",
            matching: { $0.loadedMarketIDs == [1] }
        ) {
            viewModel.onAppear()
        }

        repository.error = SearchFailure()
        await expectPublished(
            viewModel.$marketsState,
            description: "failed after sort change",
            matching: { if case .failed = $0 { true } else { false } }
        ) {
            viewModel.setSort(.openInterest)
        }
        viewModel.onDisappear()
    }

    @MainActor
    func test_emptyResult_publishesEmptyState() async {
        let repository = PerpsMarketsSearchingSpy()
        let viewModel = makeViewModel(repository: repository)

        await expectPublished(
            viewModel.$marketsState,
            description: "empty",
            matching: { if case .empty = $0 { true } else { false } }
        ) {
            viewModel.onAppear()
        }
        viewModel.onDisappear()
    }
}

private extension PerpsSearchViewModelTests {
    @MainActor
    func makeViewModel(
        repository: PerpsMarketsSearchingSpy,
        store: PerpsMarketsStore = .makeForTests()
    ) -> PerpsSearchViewModel {
        PerpsSearchViewModel(
            repository: repository,
            marketsStore: store,
            debounceNanoseconds: 50_000_000,
            format: PerpsFormatting.live
        )
    }

    func makeMarket(
        id: Int64,
        symbol: String,
        volume: Double = 10,
        priceChange: Double = 0,
        price: Double = 1
    ) -> PerpsMarketSummary {
        PerpsMarketSummary(
            marketId: id,
            symbol: symbol,
            name: symbol,
            iconURL: nil,
            maxLeverage: 20,
            price: price,
            priceChangePercent: priceChange,
            volume24h: volume
        )
    }

    @MainActor
    func expectPublished<Value>(
        _ publisher: Published<Value>.Publisher,
        description: String,
        matching predicate: @escaping (Value) -> Bool,
        perform action: @MainActor () async -> Void
    ) async {
        let published = expectation(description: description)
        var isFulfilled = false
        let cancellable = publisher.sink { value in
            guard !isFulfilled, predicate(value) else { return }
            isFulfilled = true
            published.fulfill()
        }

        await action()
        await fulfillment(of: [published], timeout: 2)
        withExtendedLifetime(cancellable) {}
    }
}

private extension PerpsSearchViewModel.MarketsState {
    var loadedItems: [PerpsMarketRowItem] {
        if case let .loaded(items, _) = self { return items }
        return []
    }

    var loadedMarketIDs: [Int64] {
        loadedItems.map(\.id)
    }
}

private struct SearchFailure: Error {}

@MainActor
private final class PerpsMarketsSearchingSpy: PerpsMarketsSearching {
    struct Request: Equatable {
        let query: String?
        let sort: PerpsMarketsSort
        let cursor: String?
        var filter: PerpsMarketFilter = .all
    }

    var handler: ((Request) async throws -> PerpsMarketsPage)?
    var pages: [String?: PerpsMarketsPage] = [:]
    var error: Error?
    private(set) var requests: [Request] = []

    func setResults(_ items: [PerpsMarketSummary], nextCursor: String? = nil) {
        pages[nil] = PerpsMarketsPage(items: items, nextCursor: nextCursor)
    }

    func markets(query: String?, sort: PerpsMarketsSort, cursor: String?, filter: PerpsMarketFilter) async throws -> PerpsMarketsPage {
        let request = Request(query: query, sort: sort, cursor: cursor, filter: filter)
        requests.append(request)
        if let handler { return try await handler(request) }
        if let error {
            throw error
        }
        return pages[cursor] ?? PerpsMarketsPage(items: [], nextCursor: nil)
    }
}
