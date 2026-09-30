@testable import KeeperCore
import XCTest

final class FakeMarkPricesClient: HermesMarkPricesStreaming, @unchecked Sendable {
    private let lock = NSLock()
    private var onUpdate: (@Sendable (HermesMarkPricesSnapshot) async -> Void)?
    private var onRejected: (@Sendable () async -> Void)?
    private(set) var tickersLog: [[String]] = []
    private(set) var cancelCount = 0
    var onSetTickers: (([String]) -> Void)?

    var latestTickers: [String]? {
        lock.withLock { tickersLog.last }
    }

    func watch(
        onUpdate: @escaping @Sendable (HermesMarkPricesSnapshot) async -> Void,
        onReconnecting _: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) -> HermesMarkPricesWatch {
        lock.withLock {
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

extension PerpsMarketsStore {
    static func makeForTests(
        service: PerpsMarketsReading? = nil,
        tickers: [Int64: String] = [:],
        client: FakeMarkPricesClient = FakeMarkPricesClient()
    ) -> PerpsMarketsStore {
        let repository = TestPerpsMarketsReading(
            base: service ?? EmptyPerpsMarketsReading(),
            tickers: tickers
        )
        return PerpsMarketsStore(
            repository: repository,
            pricesClient: client,
            priceDebounceInterval: 0
        )
    }
}

extension PerpsMarketSummary {
    static func test(
        id: Int64,
        symbol: String = "BTC",
        name: String = "",
        iconURL: URL? = nil,
        maxLeverage: Int = 20,
        price: Double = 1,
        priceChangePercent: Double = 0,
        volume24h: Double = 0
    ) -> PerpsMarketSummary {
        PerpsMarketSummary(
            marketId: id,
            symbol: symbol,
            name: name,
            iconURL: iconURL,
            maxLeverage: maxLeverage,
            price: price,
            priceChangePercent: priceChangePercent,
            volume24h: volume24h
        )
    }
}

extension PerpsMarketDetails {
    static func test(
        metadata: PerpsMarketMetadata,
        name: String = "",
        iconURL: URL? = nil,
        about: String? = nil
    ) -> PerpsMarketDetails {
        PerpsMarketDetails(metadata: metadata, name: name, iconURL: iconURL, about: about)
    }
}

extension PerpsMarketsPage {
    static func test(_ items: [PerpsMarketSummary], nextCursor: String? = nil) -> PerpsMarketsPage {
        PerpsMarketsPage(items: items, nextCursor: nextCursor)
    }
}

private final class TestPerpsMarketsReading: PerpsMarketsReading {
    private let base: PerpsMarketsReading
    private let tickers: [Int64: String]

    init(base: PerpsMarketsReading, tickers: [Int64: String]) {
        self.base = base
        self.tickers = tickers
    }

    func markets(query: String?, sort: PerpsMarketsSort, cursor: String?) async throws -> PerpsMarketsPage {
        try await base.markets(query: query, sort: sort, cursor: cursor)
    }

    func marketDetails(marketId: Int64) async throws -> PerpsMarketDetails {
        try await base.marketDetails(marketId: marketId)
    }

    func reloadMarketDetails(marketId: Int64) async throws -> PerpsMarketDetails {
        try await base.reloadMarketDetails(marketId: marketId)
    }

    func market(marketId: Int64) async -> PerpsMarketMetadata? {
        await base.market(marketId: marketId)
    }

    func tickers(for marketIds: Set<Int64>) async throws -> [Int64: String] {
        if tickers.isEmpty {
            return try await base.tickers(for: marketIds)
        }
        return tickers.filter { marketIds.contains($0.key) }
    }
}

private final class EmptyPerpsMarketsReading: PerpsMarketsReading {
    func markets(query _: String?, sort _: PerpsMarketsSort, cursor _: String?) async throws -> PerpsMarketsPage {
        .test([])
    }

    func marketDetails(marketId _: Int64) async throws -> PerpsMarketDetails {
        throw PerpsMarketsRepositoryError.marketNotFound
    }
}

extension XCTestCase {
    func waitForTickers(
        _ client: FakeMarkPricesClient,
        toEqual expected: [String],
        timeout: TimeInterval = 2
    ) async {
        if client.latestTickers == expected { return }
        let arrived = expectation(description: "tickers \(expected)")
        arrived.assertForOverFulfill = false
        client.onSetTickers = { tickers in
            if tickers == expected { arrived.fulfill() }
        }
        if client.latestTickers == expected { arrived.fulfill() }
        await fulfillment(of: [arrived], timeout: timeout)
        client.onSetTickers = nil
    }
}

extension PerpsTradingFlags {
    static let testAllEnabled: PerpsTradingFlags? = PerpsTradingFlags(
        openEnabled: true,
        closeEnabled: true,
        cancelEnabled: true,
        addMarginEnabled: true,
        removeMarginEnabled: true,
        autoCloseEnabled: true
    )
}
