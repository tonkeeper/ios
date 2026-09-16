@testable import App
import Combine
@testable import KeeperCore
import XCTest

final class PerpsSearchViewModelTests: XCTestCase {
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
                state.loadedItems.first(where: { $0.id == 2 })?.priceText == PerpsFormatting.usd(60)
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
            debounceNanoseconds: 50_000_000
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

private final class PerpsMarketsSearchingSpy: PerpsMarketsSearching, @unchecked Sendable {
    struct Request: Equatable {
        let query: String?
        let sort: PerpsMarketsSort
        let cursor: String?
    }

    var pages: [String?: PerpsMarketsPage] = [:]
    var error: Error?
    private(set) var requests: [Request] = []

    func setResults(_ items: [PerpsMarketSummary], nextCursor: String? = nil) {
        pages[nil] = PerpsMarketsPage(items: items, nextCursor: nextCursor)
    }

    func markets(query: String?, sort: PerpsMarketsSort, cursor: String?) async throws -> PerpsMarketsPage {
        requests.append(.init(query: query, sort: sort, cursor: cursor))
        if let error {
            throw error
        }
        return pages[cursor] ?? PerpsMarketsPage(items: [], nextCursor: nil)
    }
}
