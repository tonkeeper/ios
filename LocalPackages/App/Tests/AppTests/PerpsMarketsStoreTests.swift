@testable import App
@testable import KeeperCore
import XCTest

@MainActor
final class PerpsMarketsStoreTests: XCTestCase {
    func test_subscribe_loadsFirstPage_andReportsNextPage() async {
        let reading = PagedMarketsReading(pages: [
            .test([.test(id: 1, symbol: "BTC", price: 66000)], nextCursor: "p2"),
            .test([.test(id: 2, symbol: "ETH", price: 3000)]),
        ])
        let store = PerpsMarketsStore.makeForTests(service: reading)
        await subscribeUntilLoaded(store)

        guard case let .loaded(markets) = store.getState() else { return XCTFail("expected loaded markets") }
        XCTAssertEqual(markets.items.map(\.marketId), [1])
        XCTAssertTrue(markets.hasNextPage)
        XCTAssertFalse(markets.isLoadingNextPage)
        XCTAssertEqual(reading.requests, [.init(sort: .volume, cursor: nil)])
        store.unsubscribe()
    }

    func test_snapshot_readsMarketDetails() async {
        let reading = PagedMarketsReading(pages: [.test([])])
        reading.details[7] = .test(
            metadata: marketsStoreTestMetadata(id: 7, symbol: "ETH", lastTradePrice: 3421),
            name: "Ethereum"
        )
        let store = PerpsMarketsStore.makeForTests(service: reading)

        let snapshot = await store.snapshot(marketId: 7)

        if case .loaded = store.getState() {
            XCTFail("a details lookup must not publish a Home list")
        }
        XCTAssertEqual(snapshot?.marketId, 7)
        XCTAssertEqual(snapshot?.displayName, "Ethereum")
        XCTAssertEqual(snapshot?.price, 3421)
    }

    func test_sortFailure_doesNotReusePreviousCursor_andRetryStartsFromFirstPage() async {
        let reading = PagedMarketsReading(pages: [
            .test([.test(id: 1)], nextCursor: "p2"),
            .test([.test(id: 2)], nextCursor: "p3"),
        ])
        let store = PerpsMarketsStore.makeForTests(service: reading)
        await subscribeUntilLoaded(store)
        store.loadNextPage()
        await waitUntilStore(store) {
            if case let .loaded(markets) = $0 { return markets.items.map(\.marketId) == [1, 2] }
            return false
        }

        reading.failNextLoads = true
        store.setSort(.openInterest)
        await waitUntilStore(store) {
            if case .failed = $0 { return true }
            return false
        }

        reading.failNextLoads = false
        store.loadNextPage()
        store.unsubscribe()
        store.subscribe()
        await waitUntilStore(store) {
            if case let .loaded(markets) = $0 { return markets.items.map(\.marketId) == [1] }
            return false
        }
        XCTAssertEqual(reading.requests, [
            .init(sort: .volume, cursor: nil),
            .init(sort: .volume, cursor: "p2"),
            .init(sort: .openInterest, cursor: nil),
            .init(sort: .openInterest, cursor: nil),
        ])
        store.unsubscribe()
    }

    // MARK: - Helpers

    private func subscribeUntilLoaded(_ store: PerpsMarketsStore) async {
        let observer = MarketsStoreObserver()
        let loaded = expectation(description: "markets store loaded")
        loaded.assertForOverFulfill = false
        store.addObserver(
            observer,
            closure: { _, event in
                guard case .didUpdate(.loaded) = event else { return }
                loaded.fulfill()
            },
            onRegistered: { store.subscribe() }
        )

        await fulfillment(of: [loaded], timeout: 2)
        withExtendedLifetime(observer) {}
    }

    private func waitUntilStore(
        _ store: PerpsMarketsStore,
        timeout: TimeInterval = 2,
        _ condition: @escaping (PerpsMarketsStore.State) -> Bool
    ) async {
        let observer = MarketsStoreObserver()
        let fulfilled = expectation(description: "markets store condition")
        fulfilled.assertForOverFulfill = false
        store.addObserver(
            observer,
            closure: { _, event in
                if case let .didUpdate(state) = event, condition(state) {
                    fulfilled.fulfill()
                }
            },
            onRegistered: {
                if condition(store.getState()) {
                    fulfilled.fulfill()
                }
            }
        )
        await fulfillment(of: [fulfilled], timeout: timeout)
        withExtendedLifetime(observer) {}
    }
}

private final class MarketsStoreObserver {}

private func marketsStoreTestMetadata(id: Int64, symbol: String, lastTradePrice: Double) -> PerpsMarketMetadata {
    PerpsMarketMetadata(
        marketId: id,
        symbol: symbol,
        ticker: "\(symbol)/USD",
        status: "active",
        markPrice: nil,
        lastTradePrice: lastTradePrice,
        priceChangePercent: 0,
        volume24h: 0,
        openInterest: 0,
        maxLeverage: 20,
        fundingRatePercent: nil,
        priceDecimals: 2,
        sizeDecimals: 2,
        minBaseSize: 0
    )
}

private final class PagedMarketsReading: PerpsMarketsReading, @unchecked Sendable {
    struct Request: Equatable {
        let sort: PerpsMarketsSort
        let cursor: String?
    }

    private let lock = NSLock()
    private let pages: [PerpsMarketsPage]
    private var _requests: [Request] = []
    var details: [Int64: PerpsMarketDetails] = [:]
    var failNextLoads = false
    var onLoadFinished: ((Int) -> Void)?

    init(pages: [PerpsMarketsPage]) {
        self.pages = pages
    }

    var requests: [Request] {
        lock.withLock { _requests }
    }

    func markets(query _: String?, sort: PerpsMarketsSort, cursor: String?) async throws -> PerpsMarketsPage {
        let (count, shouldFail, callback) = lock.withLock { () -> (Int, Bool, ((Int) -> Void)?) in
            _requests.append(Request(sort: sort, cursor: cursor))
            return (_requests.count, failNextLoads, onLoadFinished)
        }
        defer { callback?(count) }
        if shouldFail {
            throw URLError(.badServerResponse)
        }
        let index = cursor.flatMap { Int($0.dropFirst()) }.map { $0 - 1 } ?? 0
        guard pages.indices.contains(index) else { return .test([]) }
        return pages[index]
    }

    func marketDetails(marketId: Int64) async throws -> PerpsMarketDetails {
        guard let details = lock.withLock({ details[marketId] }) else {
            throw PerpsMarketsRepositoryError.marketNotFound
        }
        return details
    }
}
