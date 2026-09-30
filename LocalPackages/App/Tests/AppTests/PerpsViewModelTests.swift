@testable import App
import ChainKit
import Combine
@testable import KeeperCore
import TonSwift
import XCTest

final class PerpsViewModelTests: XCTestCase {
    // MARK: Markets loading + paging + sort

    @MainActor
    func test_onAppear_loadsMarketsInCatalogOrder() async {
        let service = PerpsHomeServiceSpy()
        service.pages = [
            .test([
                .test(id: 2, symbol: "BBB", maxLeverage: 40, price: 30, priceChangePercent: 1, volume24h: 30),
                .test(id: 3, symbol: "CCC", price: 20, priceChangePercent: 9, volume24h: 20),
                .test(id: 1, symbol: "AAA", price: 10, priceChangePercent: 5, volume24h: 10),
            ]),
        ]
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$marketsState,
            description: "markets loaded",
            matching: { $0.loadedMarketIDs == [2, 3, 1] }
        ) {
            viewModel.onAppear()
        }
        let first = viewModel.loadedItems.first
        XCTAssertEqual(first?.leverageText, "40X")
        XCTAssertEqual(first?.priceText, PerpsFormatting.usd(30))
        XCTAssertEqual(service.requestedSorts, [.volume])
        viewModel.onDisappear()
    }

    @MainActor
    func test_setSort_reloadsMarketsWithSelectedSort() async {
        let service = PerpsHomeServiceSpy()
        service.pages = [.test([.test(id: 1, symbol: "AAA")])]
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$marketsState,
            description: "markets loaded",
            matching: { $0.loadedMarketIDs == [1] }
        ) {
            viewModel.onAppear()
        }

        viewModel.setSort(.priceChange)
        XCTAssertEqual(viewModel.sort, .priceChange)
        await service.waitForRequestCount(2)
        XCTAssertEqual(service.requestedSorts, [.volume, .priceChange])
        viewModel.onDisappear()
    }

    @MainActor
    func test_newHome_adoptsTheSharedStoresSort() async {
        let service = PerpsHomeServiceSpy()
        service.pages = [.test([.test(id: 1)])]
        let stores = makeStores(service: service)
        let first = PerpsViewModel(marketsStore: stores.markets, accountStore: stores.account)
        await expectPublished(first.$marketsState, description: "first home loaded", matching: {
            $0.loadedMarketIDs == [1]
        }) {
            first.onAppear()
        }
        first.setSort(.openInterest)
        await service.waitForRequestCount(2)
        for _ in 0 ..< 200 {
            if case let .loaded(markets) = stores.markets.getState(), markets.sort == .openInterest { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        first.onDisappear()

        let second = PerpsViewModel(marketsStore: stores.markets, accountStore: stores.account)
        XCTAssertEqual(second.sort, .openInterest)
        second.onAppear()
        await service.waitForRequestCount(3)

        XCTAssertEqual(service.requestedSorts, [.volume, .openInterest, .openInterest])
        second.onDisappear()
    }

    // MARK: Account state

    @MainActor
    func test_resolveAccount_active_exposesPortfolio() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = makePortfolio(availableBalance: "125.50")
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "account active",
            matching: \.isActive
        ) {
            viewModel.onAppear()
        }
        XCTAssertEqual(viewModel.accountState.portfolio?.accountIndex, 7)
        viewModel.onDisappear()
    }

    @MainActor
    func test_resolveAccount_noAccount_isInactive() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .noAccount(ethAddress: "0xabc")
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "account inactive",
            matching: { if case .inactive = $0 { true } else { false } }
        ) {
            viewModel.onAppear()
        }
        XCTAssertNil(viewModel.accountState.portfolio)
        viewModel.onDisappear()
    }

    // MARK: Open positions

    @MainActor
    func test_activePortfolio_exposesPositionRowsAndTotal() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = makePortfolio(
            availableBalance: "712.56",
            positions: [
                makePosition(marketId: 1, symbol: "BTC", side: .long, notionalUsd: 553.5, marginUsd: 20.5, unrealizedPnlUsd: 0.5),
                makePosition(marketId: 2, symbol: "ETH", side: .short, notionalUsd: 850, marginUsd: 106.25, unrealizedPnlUsd: 6.18),
            ]
        )
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "positions loaded",
            matching: { $0.portfolio?.positions.count == 2 }
        ) {
            viewModel.onAppear()
        }

        let portfolio = viewModel.accountState.portfolio
        let btc = portfolio?.positions.first
        XCTAssertEqual(btc?.id, 1)
        XCTAssertEqual(btc?.symbol, "BTC")
        XCTAssertEqual(btc?.isLong, true)
        XCTAssertEqual(btc?.leverageText, "27X")
        XCTAssertEqual(btc?.valueText, PerpsFormatting.usd(21))
        XCTAssertEqual(btc?.pnlText, PerpsFormatting.signedUsd(0.5))
        XCTAssertEqual(btc?.isPnlPositive, true)
        XCTAssertEqual(portfolio?.positions.last?.isLong, false)

        XCTAssertEqual(portfolio?.positionsTotal?.amountText, PerpsFormatting.usd(133.43))
        XCTAssertEqual(portfolio?.positionsTotal?.pnlText, PerpsFormatting.signedUsd(6.68))
        XCTAssertEqual(portfolio?.positionsTotal?.isPnlPositive, true)
        viewModel.onDisappear()
    }

    @MainActor
    func test_activePortfolioWithoutPositions_hasNoTotal() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = makePortfolio(availableBalance: "125.50")
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "account active",
            matching: \.isActive
        ) {
            viewModel.onAppear()
        }
        XCTAssertTrue(viewModel.accountState.portfolio?.positions.isEmpty == true)
        XCTAssertNil(viewModel.accountState.portfolio?.positionsTotal)
        viewModel.onDisappear()
    }

    @MainActor
    func test_headerTotalIsTheSumOfTheCardsBelowIt() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = makePortfolio(
            availableBalance: "712.56",
            positions: [
                makePosition(marketId: 1, symbol: "BTC", marginUsd: 20.5, unrealizedPnlUsd: 0.5),
                makePosition(marketId: 2, symbol: "ETH", marginUsd: 106.25, unrealizedPnlUsd: 6.18),
            ]
        )
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "positions loaded",
            matching: { $0.portfolio?.positionsTotal != nil }
        ) {
            viewModel.onAppear()
        }
        XCTAssertEqual(
            viewModel.accountState.portfolio?.positionsTotal?.pnlText,
            PerpsFormatting.signedUsd(6.68)
        )
        viewModel.onDisappear()
    }

    @MainActor
    func test_aPositionWithoutMargin_suppressesTheHeaderPercent() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = makePortfolio(
            availableBalance: "712.56",
            positions: [
                makePosition(marketId: 1, symbol: "BTC", marginUsd: 0, unrealizedPnlUsd: 50),
                makePosition(marketId: 2, symbol: "ETH", marginUsd: 20, unrealizedPnlUsd: 2),
            ]
        )
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "positions loaded",
            matching: { $0.portfolio?.positionsTotal != nil }
        ) {
            viewModel.onAppear()
        }
        let total = viewModel.accountState.portfolio?.positionsTotal
        XCTAssertEqual(total?.pnlText, PerpsFormatting.signedUsd(52))
        XCTAssertNil(total?.pnlPercentText)
        viewModel.onDisappear()
    }

    @MainActor
    func test_positionRowIcon_comesFromLoadedMarkets() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = makePortfolio(
            availableBalance: "712.56",
            positions: [makePosition(marketId: 1, symbol: "BTC")]
        )
        let iconURL = URL(string: "https://cache.tonapi.io/btc.png")
        service.pages = [.test([.test(id: 1, symbol: "BTC", iconURL: iconURL)])]
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "position icon resolved",
            matching: { $0.portfolio?.positions.first?.iconURL == iconURL }
        ) {
            viewModel.onAppear()
        }
        viewModel.onDisappear()
    }

    @MainActor
    func test_positionValueIsEquityWhileTheHeaderPercentStaysAgainstMargin() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = makePortfolio(
            availableBalance: "712.56",
            positions: [makePosition(marketId: 1, symbol: "BTC", marginUsd: 100, unrealizedPnlUsd: 25)]
        )
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "positions loaded",
            matching: { $0.portfolio?.positionsTotal != nil }
        ) {
            viewModel.onAppear()
        }
        let portfolio = viewModel.accountState.portfolio
        XCTAssertEqual(portfolio?.positions.first?.valueText, PerpsFormatting.usd(125))
        XCTAssertEqual(portfolio?.positionsTotal?.amountText, PerpsFormatting.usd(125))
        XCTAssertEqual(portfolio?.positionsTotal?.pnlPercentText, PerpsFormatting.signedPercent(25))
        viewModel.onDisappear()
    }

    @MainActor
    func test_positionRows_keepMarketIdOrderWhateverOrderTheBackendSends() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = makePortfolio(
            availableBalance: "712.56",
            positions: [
                makePosition(marketId: 9, symbol: "SOL"),
                makePosition(marketId: 2, symbol: "ETH"),
                makePosition(marketId: 5, symbol: "TON"),
            ]
        )
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "positions loaded",
            matching: { $0.portfolio?.positions.count == 3 }
        ) {
            viewModel.onAppear()
        }
        XCTAssertEqual(viewModel.accountState.portfolio?.positions.map(\.id), [2, 5, 9])
        XCTAssertEqual(viewModel.accountState.portfolio?.positions.map(\.symbol), ["ETH", "TON", "SOL"])
        viewModel.onDisappear()
    }

    @MainActor
    func test_manyPositions_shareASinglePositionsWatch() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = makePortfolio(
            availableBalance: "712.56",
            positions: [
                makePosition(marketId: 1, symbol: "BTC"),
                makePosition(marketId: 2, symbol: "ETH"),
            ]
        )
        let viewModel = makeViewModel(service: service)

        await expectPublished(
            viewModel.$accountState,
            description: "positions loaded",
            matching: { $0.portfolio?.positions.count == 2 }
        ) {
            viewModel.onAppear()
        }
        XCTAssertEqual(service.positionWatchStarts, 1)
        viewModel.onDisappear()
    }

    // MARK: Live prices

    @MainActor
    func test_visibleRows_driveSubscriptionWindow() async {
        let service = PerpsHomeServiceSpy()
        service.pages = [
            .test([
                .test(id: 1, symbol: "AAA", volume24h: 30),
                .test(id: 2, symbol: "BBB", volume24h: 20),
                .test(id: 3, symbol: "CCC", volume24h: 10),
            ]),
        ]
        let client = FakeMarkPricesClient()
        let viewModel = makeViewModel(service: service, client: client)

        await expectPublished(
            viewModel.$marketsState,
            description: "initial markets loaded",
            matching: { $0.loadedMarketIDs == [1, 2, 3] }
        ) {
            viewModel.onAppear()
        }

        viewModel.rowAppeared(1)
        viewModel.rowAppeared(2)
        await waitForTickers(client, toEqual: ["AAA/USD", "BBB/USD"])

        viewModel.rowDisappeared(1)
        viewModel.rowAppeared(3)
        await waitForTickers(client, toEqual: ["BBB/USD", "CCC/USD"])
        viewModel.onDisappear()
    }

    @MainActor
    func test_livePriceTick_patchesRowInPlace_withoutReordering() async {
        let service = PerpsHomeServiceSpy()
        service.pages = [
            .test([
                .test(id: 1, symbol: "AAA", price: 100, priceChangePercent: 5, volume24h: 30),
                .test(id: 2, symbol: "BBB", price: 100, priceChangePercent: 1, volume24h: 20),
            ]),
        ]
        let client = FakeMarkPricesClient()
        let viewModel = makeViewModel(service: service, client: client)

        await expectPublished(
            viewModel.$marketsState,
            description: "initial markets loaded",
            matching: { $0.loadedMarketIDs == [1, 2] }
        ) {
            viewModel.onAppear()
        }

        viewModel.rowAppeared(1)
        viewModel.rowAppeared(2)
        await waitForTickers(client, toEqual: ["AAA/USD", "BBB/USD"])

        await expectPublished(
            viewModel.$marketsState,
            description: "price patched in place",
            matching: { state in
                state.loadedItems.first(where: { $0.id == 2 })?.priceText == PerpsFormatting.usd(150)
            }
        ) {
            await client.emit([("BBB/USD", "150")])
        }
        XCTAssertEqual(viewModel.loadedMarketIDs, [1, 2])
        let pumped = viewModel.loadedItems.first(where: { $0.id == 2 })
        XCTAssertEqual(pumped?.changeText, PerpsFormatting.signedPercent(51.5))
        viewModel.onDisappear()
    }
}

// MARK: - Helpers

private extension PerpsViewModel {
    var loadedMarketIDs: [Int64] {
        marketsState.loadedMarketIDs
    }

    var loadedItems: [PerpsViewModel.MarketItem] {
        marketsState.loadedItems
    }
}

private extension PerpsViewModel.MarketsState {
    var loadedMarketIDs: [Int64] {
        loadedItems.map(\.id)
    }

    var loadedItems: [PerpsViewModel.MarketItem] {
        if case let .loaded(items, _) = self { return items }
        return []
    }
}

private extension PerpsViewModelTests {
    @MainActor
    func makeStores(
        service: PerpsHomeServiceSpy,
        client: FakeMarkPricesClient = FakeMarkPricesClient()
    ) -> (markets: PerpsMarketsStore, account: PerpsAccountStore) {
        let wallet = Wallet.perpsTest()
        let tickers = service.pages.flatMap(\.items).reduce(into: [Int64: String]()) { result, market in
            result[market.marketId] = "\(market.symbol)/USD"
        }
        return (
            PerpsMarketsStore.makeForTests(service: service, tickers: tickers, client: client),
            PerpsAccountStore(service: service, wallet: wallet)
        )
    }

    @MainActor
    func makeViewModel(
        service: PerpsHomeServiceSpy,
        client: FakeMarkPricesClient = FakeMarkPricesClient()
    ) -> PerpsViewModel {
        let stores = makeStores(service: service, client: client)
        return PerpsViewModel(
            marketsStore: stores.markets,
            accountStore: stores.account
        )
    }

    func makePortfolio(
        availableBalance: String,
        positions: [PerpsPositionSummary] = []
    ) -> PerpsAccountSnapshot {
        PerpsAccountSnapshot(availableBalance: availableBalance, positions: positions)
    }

    func makePosition(
        marketId: Int64 = 1,
        symbol: String = "BTC",
        side: PerpsTradeSide = .long,
        baseSize: Double = 0.008164,
        notionalUsd: Double = 553.5,
        marginUsd: Double = 20.5,
        unrealizedPnlUsd: Double = 0.5,
        leverage: Double? = 27
    ) -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:\(marketId)",
            marketId: marketId,
            symbol: symbol,
            side: side,
            baseSize: baseSize,
            notionalUsd: notionalUsd,
            marginUsd: marginUsd,
            equityUsd: marginUsd + unrealizedPnlUsd,
            leverage: leverage,
            roiPercent: 2.5,
            entryPrice: 66541.7,
            liquidationPrice: 64141.75,
            unrealizedPnlUsd: unrealizedPnlUsd,
            realizedPnlUsd: 0,
            fundingPaidUsd: 0
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

private extension Wallet {
    static func perpsTest() -> Wallet {
        let raw = Data("perps-test-public-key".utf8)
        let padded = raw + Data(repeating: 0, count: max(0, 32 - raw.count))
        let publicKey = TonSwift.PublicKey(data: Data(padded.prefix(32)))
        return Wallet(
            id: "perps-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Perps Test", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class PerpsHomeServiceSpy: PerpsMarketsReading, PerpsAccountReading, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [(sort: PerpsMarketsSort, cursor: String?)] = []
    private var requestWaiters: [(needed: Int, resume: () -> Void)] = []

    private var positionWatchStartCount = 0

    var statusResult: PerpsAccountStatus = .unknown
    var portfolioResult: PerpsAccountSnapshot?
    var pages: [PerpsMarketsPage] = []

    var requestedSorts: [PerpsMarketsSort] {
        lock.withLock { requests.map(\.sort) }
    }

    var positionWatchStarts: Int {
        lock.withLock { positionWatchStartCount }
    }

    func waitForRequestCount(_ count: Int) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if requests.count >= count {
                lock.unlock()
                continuation.resume()
                return
            }
            requestWaiters.append((count, { continuation.resume() }))
            lock.unlock()
        }
    }

    func status(wallet _: Wallet) async -> PerpsAccountStatus {
        statusResult
    }

    func portfolio(wallet _: Wallet) async throws -> PerpsAccountSnapshot? {
        portfolioResult
    }

    func tradingSnapshot(wallet _: Wallet, marketId _: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
    }

    func recentActivity(wallet _: Wallet, marketId _: Int64, limit _: Int) async throws -> [PerpsActivityItem] {
        []
    }

    func watchPositions(
        wallet _: Wallet,
        onUpdate _: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onInterrupted _: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        lock.withLock { positionWatchStartCount += 1 }
        return PerpsPositionsWatch {}
    }

    func markets(query _: String?, sort: PerpsMarketsSort, cursor: String?) async throws -> PerpsMarketsPage {
        let ready = lock.withLock { () -> [() -> Void] in
            requests.append((sort, cursor))
            let count = requests.count
            let ready = requestWaiters.filter { $0.needed <= count }.map(\.resume)
            requestWaiters.removeAll { $0.needed <= count }
            return ready
        }
        ready.forEach { $0() }
        let index = cursor.flatMap { Int($0.dropFirst()) }.map { $0 - 1 } ?? 0
        guard pages.indices.contains(index) else { return .test([]) }
        return pages[index]
    }

    func marketDetails(marketId _: Int64) async throws -> PerpsMarketDetails {
        throw PerpsMarketsRepositoryError.marketNotFound
    }
}
