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
        let first = PerpsViewModel(marketsStore: stores.markets, accountStore: stores.account, isTestnet: false)
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

        let second = PerpsViewModel(marketsStore: stores.markets, accountStore: stores.account, isTestnet: false)
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
        service.statusResult = .active(accountIndex: 7, apiKeyIndex: 3)
        service.portfolioResult = makePortfolio(accountIndex: 7, availableBalance: "125.50")
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
            matching: \.showsActivationControls
        ) {
            viewModel.onAppear()
        }
        viewModel.onDisappear()
    }

    // MARK: Activation

    @MainActor
    func test_activation_success_becomesActiveAndShowsSuccessToast() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .noAccount(ethAddress: "0xabc")
        service.portfolioResult = makePortfolio(accountIndex: 9, availableBalance: "50")
        let stores = makeStores(service: service)
        let viewModel = PerpsViewModel(
            marketsStore: stores.markets,
            accountStore: stores.account,
            isTestnet: false
        )

        await expectPublished(
            viewModel.$accountState,
            description: "account inactive",
            matching: \.showsActivationControls
        ) {
            viewModel.onAppear()
        }
        await expectPublished(
            viewModel.$accountState,
            description: "account activating",
            matching: \.isActivating
        ) {
            stores.account.beginActivation()
        }
        await expectPublished(
            viewModel.$accountState,
            description: "account activated",
            matching: \.isActive
        ) {
            await stores.account.applyActivation(.active(accountIndex: 9, apiKeyIndex: 3))
        }
        XCTAssertEqual(viewModel.activationToast, .success)
        viewModel.onDisappear()
    }

    @MainActor
    func test_activation_canceled_returnsToInactiveWithoutToast() async {
        let service = PerpsHomeServiceSpy()
        service.statusResult = .noAccount(ethAddress: "0xabc")
        let stores = makeStores(service: service)
        let viewModel = PerpsViewModel(
            marketsStore: stores.markets,
            accountStore: stores.account,
            isTestnet: false
        )

        await expectPublished(
            viewModel.$accountState,
            description: "account inactive",
            matching: \.showsActivationControls
        ) {
            viewModel.onAppear()
        }
        await expectPublished(
            viewModel.$accountState,
            description: "account activating",
            matching: \.isActivating
        ) {
            stores.account.beginActivation()
        }
        await expectPublished(
            viewModel.$accountState,
            description: "activation canceled",
            matching: \.showsActivationControls
        ) {
            await stores.account.applyActivation(.canceled)
        }
        XCTAssertNil(viewModel.activationToast)
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
            accountStore: stores.account,
            isTestnet: false
        )
    }

    func makePortfolio(accountIndex: Int64, availableBalance: String) -> PerpsPortfolio {
        PerpsPortfolio(
            accountIndex: accountIndex,
            collateral: "0",
            availableBalance: availableBalance,
            totalAssetValue: availableBalance,
            positions: []
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

    var statusResult: LighterPerpsStatus = .unknown
    var portfolioResult: PerpsPortfolio?
    var pages: [PerpsMarketsPage] = []

    var requestedSorts: [PerpsMarketsSort] {
        lock.withLock { requests.map(\.sort) }
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

    func status(wallet _: Wallet) async -> LighterPerpsStatus {
        statusResult
    }

    func portfolio(wallet _: Wallet, accountIndex _: Int64) async throws -> PerpsPortfolio? {
        portfolioResult
    }

    func activeTriggerOrders(wallet _: Wallet, accountIndex _: Int64, marketId _: Int64) async throws -> [PerpsTriggerOrderSummary] {
        []
    }

    func recentActivity(wallet _: Wallet, accountIndex _: Int64, marketId _: Int64, limit _: Int) async throws -> [PerpsActivityItem] {
        []
    }

    func watchPositions(
        wallet _: Wallet,
        accountIndex _: Int64,
        onUpdate _: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onReconnecting _: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        PerpsPositionsWatch {}
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
