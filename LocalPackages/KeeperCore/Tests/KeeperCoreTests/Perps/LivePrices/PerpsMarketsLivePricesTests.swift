@testable import KeeperCore
import XCTest

final class PerpsMarketsLivePricesTests: XCTestCase {
    func test_subscription_subscribesSortedTickersForVisibleMarkets() async {
        let client = ClientFake()
        let store = makeStore(client: client)
        let subscription = store.makePriceInterest()

        subscription.set(marketIds: [2, 1])
        await waitForTickers(client, toEqual: ["AAA/USD", "BBB/USD"])
    }

    func test_unionAcrossSubscriptions_andShrinkOnClear() async {
        let client = ClientFake()
        let store = makeStore(client: client)
        let list = store.makePriceInterest()
        let assetPage = store.makePriceInterest()

        list.set(marketIds: [1])
        await waitForTickers(client, toEqual: ["AAA/USD"])

        assetPage.set(marketIds: [2])
        await waitForTickers(client, toEqual: ["AAA/USD", "BBB/USD"])

        list.clear()
        await waitForTickers(client, toEqual: ["BBB/USD"])
    }

    func test_prices_arePublishedByMarketId_andUnknownTickersDropped() async {
        let client = ClientFake()
        let store = makeStore(client: client)
        let subscription = store.makePriceInterest()
        subscription.set(marketIds: [1, 2])
        await waitForTickers(client, toEqual: ["AAA/USD", "BBB/USD"])

        let updated = expectationForPriceUpdate(store) { state in
            state.price(marketId: 1) == 101.5 && state.price(marketId: 2) == nil
        }
        await client.emit([("AAA/USD", "101.5"), ("UNKNOWN/USD", "7")])
        await fulfillment(of: [updated], timeout: 2)

        let firstPrice = await store.price(marketId: 1)
        let secondPrice = await store.price(marketId: 2)
        XCTAssertEqual(firstPrice, 101.5)
        XCTAssertNil(secondPrice)
    }

    func test_pricesForDroppedMarkets_areRetained() async {
        let client = ClientFake()
        let store = makeStore(client: client)
        let subscription = store.makePriceInterest()
        subscription.set(marketIds: [1, 2])
        await waitForTickers(client, toEqual: ["AAA/USD", "BBB/USD"])

        let updated = expectationForPriceUpdate(store) { state in
            state.price(marketId: 1) != nil && state.price(marketId: 2) != nil
        }
        await client.emit([("AAA/USD", "1"), ("BBB/USD", "2")])
        await fulfillment(of: [updated], timeout: 2)

        let retained = expectationForPriceUpdate(store) { state in
            state.price(marketId: 2) == 2 && state.price(marketId: 1) == 1
        }
        subscription.set(marketIds: [1])
        await fulfillment(of: [retained], timeout: 2)
    }

    func test_lastSubscriptionCleared_cancelsWatch_andRetainsLastPrice() async {
        let client = ClientFake()
        let store = makeStore(client: client)
        let subscription = store.makePriceInterest()
        subscription.set(marketIds: [1])
        await waitForTickers(client, toEqual: ["AAA/USD"])

        let updated = expectationForPriceUpdate(store) { $0.price(marketId: 1) != nil }
        await client.emit([("AAA/USD", "1")])
        await fulfillment(of: [updated], timeout: 2)

        let retained = expectationForPriceUpdate(store) { $0.price(marketId: 1) == 1 }
        subscription.clear()
        await fulfillment(of: [retained], timeout: 2)
        XCTAssertEqual(client.cancelCount, 1)
    }

    func test_rejectedWatch_isRecreatedOnRepeatedInterest_andByRetry() async {
        let client = ClientFake()
        let store = makeStore(client: client)
        let subscription = store.makePriceInterest()
        subscription.set(marketIds: [1])
        await waitForTickers(client, toEqual: ["AAA/USD"])

        await client.reject()

        subscription.set(marketIds: [1])
        await waitForTickers(client, toEqual: ["AAA/USD"], minimumUpdates: 2)
        XCTAssertEqual(client.watchCount, 2)

        let updated = expectationForPriceUpdate(store) { $0.price(marketId: 1) == 123 }
        await client.emit([("AAA/USD", "123")])
        await fulfillment(of: [updated], timeout: 2)

        await client.reject()
        await waitForTickers(client, toEqual: ["AAA/USD"], minimumUpdates: 3)
        XCTAssertEqual(client.watchCount, 3)
    }

    func test_assetOutsideCatalog_createsPriceSubscription_andSharesExistingWatch() async {
        let client = ClientFake()
        let store = makeStore(client: client, catalogMarketIds: [])
        let page = store.makePriceInterest()
        let loaded = expectationForPriceUpdate(store) {
            if case let .loaded(markets) = $0 { return markets.items.isEmpty }
            return false
        }
        page.set(marketIds: [2])
        await waitForTickers(client, toEqual: ["BBB/USD"])
        await fulfillment(of: [loaded], timeout: 2)

        let updated = expectationForPriceUpdate(store) { $0.price(marketId: 2) == 42 }
        await client.emit([("BBB/USD", "42")])
        await fulfillment(of: [updated], timeout: 2)

        let confirmation = store.makePriceInterest()
        confirmation.set(marketIds: [2])
        page.set(marketIds: [1, 2])
        await waitForTickers(client, toEqual: ["AAA/USD", "BBB/USD"])
        XCTAssertEqual(client.watchCount, 1)
    }

    // MARK: - Helpers

    private func makeStore(client: ClientFake, catalogMarketIds: Set<Int64>? = nil) -> PerpsMarketsStore {
        PerpsMarketsStore(
            repository: MarketsReadingFake(tickers: [
                1: "AAA/USD",
                2: "BBB/USD",
            ], catalogMarketIds: catalogMarketIds),
            pricesClient: client,
            priceDebounceInterval: 0,
            rejectedWatchRetryInterval: 0.05
        )
    }

    private func expectationForPriceUpdate(
        _ store: PerpsMarketsStore,
        matching predicate: @escaping (PerpsMarketsStore.State) -> Bool
    ) -> XCTestExpectation {
        let updated = expectation(description: "prices updated")
        updated.assertForOverFulfill = false
        let observer = ObserverBox()
        store.addObserver(observer) { _, event in
            guard case let .didUpdate(state) = event, predicate(state) else { return }
            updated.fulfill()
        }
        observers.append(observer)
        return updated
    }

    private var observers: [ObserverBox] = []

    override func tearDown() {
        observers = []
        super.tearDown()
    }

    private func waitForTickers(
        _ client: ClientFake,
        toEqual expected: [String],
        minimumUpdates: Int = 1,
        timeout: TimeInterval = 2
    ) async {
        if client.latestTickers == expected, client.tickerUpdatesCount >= minimumUpdates { return }
        let arrived = expectation(description: "tickers \(expected)")
        arrived.assertForOverFulfill = false
        client.onSetTickers = { tickers in
            if tickers == expected, client.tickerUpdatesCount >= minimumUpdates { arrived.fulfill() }
        }
        if client.latestTickers == expected, client.tickerUpdatesCount >= minimumUpdates { arrived.fulfill() }
        await fulfillment(of: [arrived], timeout: timeout)
        client.onSetTickers = nil
    }
}

private final class ObserverBox {}

private final class MarketsReadingFake: PerpsMarketsReading {
    private let tickers: [Int64: String]
    private let catalogMarketIds: Set<Int64>

    init(tickers: [Int64: String], catalogMarketIds: Set<Int64>? = nil) {
        self.tickers = tickers
        self.catalogMarketIds = catalogMarketIds ?? Set(tickers.keys)
    }

    func markets(query _: String?, sort _: PerpsMarketsSort, cursor _: String?) async throws -> PerpsMarketsPage {
        PerpsMarketsPage(
            items: catalogMarketIds.sorted().map { marketId in
                PerpsMarketSummary(
                    marketId: marketId,
                    symbol: tickers[marketId] ?? "",
                    name: "",
                    iconURL: nil,
                    maxLeverage: 20,
                    price: 0,
                    priceChangePercent: 0,
                    volume24h: 0
                )
            },
            nextCursor: nil
        )
    }

    func marketDetails(marketId _: Int64) async throws -> PerpsMarketDetails {
        throw PerpsMarketsRepositoryError.marketNotFound
    }

    func tickers(for marketIds: Set<Int64>) async throws -> [Int64: String] {
        tickers.filter { marketIds.contains($0.key) }
    }
}

private final class ClientFake: HermesMarkPricesStreaming, @unchecked Sendable {
    private let lock = NSLock()
    private var onUpdate: (@Sendable (HermesMarkPricesSnapshot) async -> Void)?
    private var onRejected: (@Sendable () async -> Void)?
    private(set) var tickersLog: [[String]] = []
    private(set) var cancelCount = 0
    private var _watchCount = 0
    var onSetTickers: (([String]) -> Void)?

    var latestTickers: [String]? {
        lock.withLock { tickersLog.last }
    }

    var tickerUpdatesCount: Int {
        lock.withLock { tickersLog.count }
    }

    var watchCount: Int {
        lock.withLock { _watchCount }
    }

    func watch(
        onUpdate: @escaping @Sendable (HermesMarkPricesSnapshot) async -> Void,
        onReconnecting _: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) -> HermesMarkPricesWatch {
        lock.withLock {
            _watchCount += 1
            self.onUpdate = onUpdate
            self.onRejected = onRejected
        }
        return HermesMarkPricesWatch(
            onSetTickers: { [weak self] tickers in
                guard let self else { return }
                let callback = self.lock.withLock { () -> (([String]) -> Void)? in
                    self.tickersLog.append(tickers)
                    return self.onSetTickers
                }
                callback?(tickers)
            },
            onCancel: { [weak self] in
                guard let self else { return }
                self.lock.withLock { self.cancelCount += 1 }
            }
        )
    }

    func emit(_ prices: [(ticker: String, price: String)]) async {
        let callback = lock.withLock { (onUpdate, tickersLog.last ?? []) }
        await callback.0?(
            HermesMarkPricesSnapshot(
                tickers: callback.1,
                prices: prices.map { HermesTickerPrice(ticker: $0.ticker, price: $0.price) }
            )
        )
    }

    func reject() async {
        let handler = lock.withLock { onRejected }
        await handler?()
    }
}
