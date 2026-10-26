@testable import App
import Combine
@testable import KeeperCore
@testable import Perps
import PerpsModels
import TonSwift
import XCTest

final class MultichainWalletPerpsSectionViewModelTests: XCTestCase {
    @MainActor
    func test_withoutPositions_showsTheTradingShelf() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(availableBalance: "712.56")
        let viewModel = makeViewModel(
            service: service,
            shelfMarkets: [.test(id: 1, symbol: "BTC")],
            perpsFiatPrice: ["USD": "712.56"]
        )

        await expectPublished(viewModel.$content, description: "shelf shown") {
            if case let .shelf(markets) = $0 { return markets.map(\.symbol) == ["BTC"] }
            return false
        } perform: {
            viewModel.onAppear()
        }
        XCTAssertEqual(viewModel.balanceText, Self.fiatText(712.56))
        viewModel.onDisappear()
    }

    @MainActor
    func test_withPositions_showsTheSameRowsAsPerpsHome() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(
            availableBalance: "712.56",
            positions: [.test(marketId: 1, symbol: "BTC", side: .long, marginUsd: 20.5, equityUsd: 21, unrealizedPnlUsd: 0.5)]
        )
        let viewModel = makeViewModel(service: service, shelfMarkets: [.test(id: 9, symbol: "ETH")])

        await expectPublished(viewModel.$content, description: "positions shown") {
            if case let .positions(positions) = $0 { return positions.count == 1 }
            return false
        } perform: {
            viewModel.onAppear()
        }
        guard case let .positions(positions) = viewModel.content else {
            return XCTFail("expected positions")
        }
        XCTAssertEqual(positions.first?.symbol, "BTC")
        XCTAssertEqual(positions.first?.valueText, PerpsFormatting.live.usd(21))
        XCTAssertEqual(positions.first?.pnlText, PerpsFormatting.live.signedUsd(0.5))
        viewModel.onDisappear()
    }

    @MainActor
    func test_secureMode_masksTheBalanceAndPositionAmountsAndFollowsTheToggle() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(
            availableBalance: "712.56",
            positions: [.test(marketId: 1, symbol: "BTC", side: .long, marginUsd: 20.5, equityUsd: 21, unrealizedPnlUsd: 0.5)]
        )
        let appSettingsStore = AppSettingsStore(
            keeperInfoStore: KeeperInfoStore(keeperInfoRepository: PerpsSectionKeeperInfoRepositoryStub())
        )
        let viewModel = makeViewModel(
            service: service,
            shelfMarkets: [],
            perpsFiatPrice: ["USD": "712.56"],
            appSettingsStore: appSettingsStore
        )

        await expectPublished(viewModel.$content, description: "positions shown") {
            if case let .positions(positions) = $0 { return positions.count == 1 }
            return false
        } perform: {
            viewModel.onAppear()
        }
        XCTAssertEqual(viewModel.balanceText, Self.fiatText(712.56))

        await expectPublished(viewModel.$content, description: "positions masked") {
            if case let .positions(positions) = $0 { return positions.first?.valueText == .secureModeValueShort }
            return false
        } perform: {
            Self.setSecureMode(true, in: appSettingsStore)
        }
        guard case let .positions(masked) = viewModel.content else {
            return XCTFail("expected positions")
        }
        XCTAssertEqual(masked.first?.symbol, "BTC")
        XCTAssertEqual(masked.first?.pnlText, .secureModeValueShort)
        XCTAssertNil(masked.first?.isPnlPositive)
        XCTAssertEqual(viewModel.balanceText, .secureModeValueShort)

        await expectPublished(viewModel.$content, description: "positions unmasked") {
            if case let .positions(positions) = $0 { return positions.first?.valueText == PerpsFormatting.live.usd(21) }
            return false
        } perform: {
            Self.setSecureMode(false, in: appSettingsStore)
        }
        XCTAssertEqual(viewModel.balanceText, Self.fiatText(712.56))
        viewModel.onDisappear()
    }

    @MainActor
    func test_anEmptyShelfResponse_isNotRequestedAgainOnEveryAccountUpdate() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(availableBalance: "0")
        let viewModel = makeViewModel(service: service, shelfMarkets: [])

        viewModel.onAppear()
        for _ in 0 ..< 40 {
            if service.shelfLoadCount >= 1 { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        for _ in 0 ..< 5 {
            service.accountStore?.refresh()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(service.shelfLoadCount, 1)
        viewModel.onDisappear()
    }

    @MainActor
    func test_aFailedShelfLoad_isNotRetriedOnEveryAccountUpdate() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(availableBalance: "0")
        service.shelfLoadFails = true
        let viewModel = makeViewModel(service: service, shelfMarkets: [])

        viewModel.onAppear()
        for _ in 0 ..< 40 {
            if service.shelfLoadCount >= 1 { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        for _ in 0 ..< 5 {
            service.accountStore?.refresh()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(service.shelfLoadCount, 1)
        viewModel.onDisappear()
    }

    @MainActor
    func test_refresh_retriesAFailedShelfLoad() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(availableBalance: "0")
        service.shelfLoadFails = true
        let viewModel = makeViewModel(service: service, shelfMarkets: [.test(id: 1, symbol: "BTC")])

        viewModel.onAppear()
        await waitForShelfLoad(service)
        service.shelfLoadFails = false
        await retryShelfLoad(viewModel, service: service, description: "shelf retry")
    }

    @MainActor
    func test_refresh_retriesAShelfLoadThatIsStillInFlight() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(availableBalance: "0")
        service.shelfLoadFails = true
        service.shelfLoadDelayNanoseconds = 100_000_000
        let viewModel = makeViewModel(service: service, shelfMarkets: [.test(id: 1, symbol: "BTC")])

        viewModel.onAppear()
        await waitForShelfLoad(service)
        service.shelfLoadFails = false
        await retryShelfLoad(viewModel, service: service, description: "in-flight shelf retry")
    }

    @MainActor
    func test_refresh_retriesAFailedShelfLoadForAnInactiveAccount() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .noAccount(ethAddress: "0xabc")
        service.shelfLoadFails = true
        let viewModel = makeViewModel(service: service, shelfMarkets: [.test(id: 1, symbol: "BTC")])

        viewModel.onAppear()
        await waitForShelfLoad(service)
        service.shelfLoadFails = false
        await retryShelfLoad(viewModel, service: service, description: "inactive shelf retry")
    }

    @MainActor
    func test_anUnresolvedAccount_doesNotFlashTheShelf() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(
            availableBalance: "712.56",
            positions: [.test(marketId: 1, symbol: "BTC")]
        )
        let viewModel = makeViewModel(service: service, shelfMarkets: [.test(id: 9, symbol: "ETH")])

        var sawShelf = false
        let cancellable = viewModel.$content.sink {
            if case .shelf = $0 { sawShelf = true }
        }
        await expectPublished(viewModel.$content, description: "positions shown") {
            if case .positions = $0 { return true }
            return false
        } perform: {
            viewModel.onAppear()
        }

        XCTAssertFalse(sawShelf, "an account still resolving must not fall back to the shelf")
        withExtendedLifetime(cancellable) {}
        viewModel.onDisappear()
    }

    @MainActor
    func test_anInactiveAccount_doesNotPollPositions() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .noAccount(ethAddress: "0xabc")
        let viewModel = makeViewModel(service: service, shelfMarkets: [.test(id: 1, symbol: "BTC")])

        await expectPublished(viewModel.$content, description: "shelf shown") {
            if case .shelf = $0 { return true }
            return false
        } perform: {
            viewModel.onAppear()
        }
        XCTAssertEqual(service.positionWatchStarts, 0)
        XCTAssertNil(viewModel.balanceText)
        viewModel.onDisappear()
    }

    @MainActor
    func test_manyPositions_shareASinglePositionsWatch() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(
            availableBalance: "712.56",
            positions: [
                .test(marketId: 1, symbol: "BTC"),
                .test(marketId: 2, symbol: "ETH"),
            ]
        )
        let viewModel = makeViewModel(service: service, shelfMarkets: [])

        await expectPublished(viewModel.$content, description: "positions shown") {
            if case let .positions(positions) = $0 { return positions.count == 2 }
            return false
        } perform: {
            viewModel.onAppear()
        }
        XCTAssertEqual(service.positionWatchStarts, 1)
        viewModel.onDisappear()
    }

    @MainActor
    func test_theTitleCarriesThePerpsFiatOfTheWalletAssets_notTheAccountFigures() async {
        let service = PerpsSectionServiceSpy()
        service.statusResult = .account(accountIndex: 7)
        service.portfolioResult = PerpsAccountSnapshot(
            availableBalance: "112.56",
            equity: "2712.12",
            positions: [.test(marketId: 1, symbol: "BTC", side: .long, marginUsd: 2599.56, unrealizedPnlUsd: 0.5)]
        )
        let viewModel = makeViewModel(
            service: service,
            shelfMarkets: [],
            perpsFiatPrice: ["USD": "2712.30", "EUR": "2495.32"]
        )

        await expectPublished(viewModel.$content, description: "positions shown") {
            if case let .positions(positions) = $0 { return positions.count == 1 }
            return false
        } perform: {
            viewModel.onAppear()
        }
        XCTAssertEqual(viewModel.balanceText, Self.fiatText(2712.30))
        viewModel.onDisappear()
    }
}

private extension MultichainWalletPerpsSectionViewModelTests {
    @MainActor
    func waitForShelfLoad(_ service: PerpsSectionServiceSpy) async {
        for _ in 0 ..< 40 {
            if service.shelfLoadCount >= 1 { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(service.shelfLoadCount, 1)
    }

    @MainActor
    func retryShelfLoad(
        _ viewModel: MultichainWalletPerpsSectionViewModel,
        service: PerpsSectionServiceSpy,
        description: String
    ) async {
        await expectPublished(viewModel.$content, description: description) {
            if case let .shelf(markets) = $0 { return markets.map(\.symbol) == ["BTC"] }
            return false
        } perform: {
            viewModel.refresh()
        }
        XCTAssertEqual(service.shelfLoadCount, 2)
        viewModel.onDisappear()
    }

    static func setSecureMode(_ isSecureMode: Bool, in store: AppSettingsStore) {
        var state = store.getState()
        state.isSecureMode = isSecureMode
        store.setStateNotifying(state, event: { .didUpdateIsSecureMode(isSecureMode: $0.isSecureMode) })
    }

    static func fiatText(_ amount: Decimal) -> String {
        FormattersAssembly().amountFormatter.format(
            decimal: amount,
            accessory: .fiat(Currency.defaultCurrency),
            style: .fiatBalance
        )
    }

    @MainActor
    func makeViewModel(
        service: PerpsSectionServiceSpy,
        shelfMarkets: [PerpsMarketSummary],
        perpsFiatPrice: [String: String]? = nil,
        appSettingsStore: AppSettingsStore? = nil
    ) -> MultichainWalletPerpsSectionViewModel {
        let wallet = Wallet.perpsSectionTest()
        let accountStore = PerpsAccountStore(service: service, wallet: wallet)
        service.accountStore = accountStore
        let keeperInfoStore = KeeperInfoStore(keeperInfoRepository: PerpsSectionKeeperInfoRepositoryStub())
        let portfolioStore = MultichainPortfolioStore(
            walletsStore: WalletsStore(keeperInfoStore: keeperInfoStore),
            repository: PerpsSectionPortfolioRepositoryStub()
        )
        portfolioStore.setPortfolio(
            MultichainPortfolio(
                fiatPrice: [:],
                assets: [],
                accountsIdentifier: "",
                currencyCode: "usd",
                hidesDustBalances: false,
                perpsFiatPrice: perpsFiatPrice
            ),
            wallet: wallet
        )
        return MultichainWalletPerpsSectionViewModel(
            wallet: wallet,
            portfolioStore: portfolioStore,
            currencyStore: CurrencyStore(keeperInfoStore: keeperInfoStore),
            appSettingsStore: appSettingsStore ?? AppSettingsStore(keeperInfoStore: keeperInfoStore),
            amountFormatter: FormattersAssembly().amountFormatter,
            accountStore: accountStore,
            marketsStore: PerpsMarketsStore.makeForTests(service: service),
            itemsMapper: TradeItemsMapper(
                multichainEnabled: true,
                signedAmountFormatter: FormattersAssembly().signedAmountFormatter
            ),
            shelfMarketsLoader: {
                service.recordShelfLoad()
                if service.shelfLoadDelayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: service.shelfLoadDelayNanoseconds)
                }
                if service.shelfLoadFails { throw PerpsMarketsRepositoryError.marketNotFound }
                return shelfMarkets
            }
        )
    }

    @MainActor
    func expectPublished<Value>(
        _ publisher: Published<Value>.Publisher,
        description: String,
        matching predicate: @escaping (Value) -> Bool,
        perform action: @MainActor () -> Void
    ) async {
        let published = expectation(description: description)
        var isFulfilled = false
        let cancellable = publisher.sink { value in
            guard !isFulfilled, predicate(value) else { return }
            isFulfilled = true
            published.fulfill()
        }
        action()
        await fulfillment(of: [published], timeout: 2)
        withExtendedLifetime(cancellable) {}
    }
}

private struct PerpsSectionKeeperInfoRepositoryStub: KeeperInfoRepository {
    struct NoKeeperInfo: Error {}

    func getKeeperInfo() throws -> KeeperInfo {
        throw NoKeeperInfo()
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}
    func removeKeeperInfo() throws {}
}

private final class PerpsSectionPortfolioRepositoryStub: MultichainPortfolioRepository {
    struct NoPortfolio: Error {}

    func getPortfolio(walletId _: String) throws -> MultichainPortfolio {
        throw NoPortfolio()
    }

    func savePortfolio(_: MultichainPortfolio, walletId _: String) throws {}
}

private final class PerpsSectionServiceSpy: PerpsMarketsReading, PerpsAccountReading, @unchecked Sendable {
    private let lock = NSLock()
    private var positionWatchStartCount = 0
    private var shelfLoadCallCount = 0

    var statusResult: PerpsAccountStatus = .unknown
    var portfolioResult: PerpsAccountSnapshot?
    var shelfLoadFails = false
    var shelfLoadDelayNanoseconds: UInt64 = 0
    weak var accountStore: PerpsAccountStore?

    var positionWatchStarts: Int {
        lock.withLock { positionWatchStartCount }
    }

    var shelfLoadCount: Int {
        lock.withLock { shelfLoadCallCount }
    }

    func recordShelfLoad() {
        lock.withLock { shelfLoadCallCount += 1 }
    }

    func status(wallet _: Wallet) async -> PerpsAccountStatus {
        statusResult
    }

    func portfolio(wallet _: Wallet) async throws -> PerpsAccountSnapshot? {
        portfolioResult
    }

    func watchPositions(
        wallet _: Wallet,
        pollInterval _: TimeInterval,
        focus _: @escaping @Sendable () -> PerpsWatchFocus,
        onUpdate _: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted _: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        lock.withLock { positionWatchStartCount += 1 }
        return PerpsPositionsWatch {}
    }

    func tradingSnapshot(wallet _: Wallet, marketId _: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
    }

    func markets(query _: String?, sort _: PerpsMarketsSort, cursor _: String?) async throws -> PerpsMarketsPage {
        .test([])
    }

    func marketDetails(marketId _: Int64) async throws -> PerpsMarketDetails {
        throw PerpsMarketsRepositoryError.marketNotFound
    }
}

private extension Wallet {
    static func perpsSectionTest() -> Wallet {
        let raw = Data("perps-section-test-key".utf8)
        let padded = raw + Data(repeating: 0, count: max(0, 32 - raw.count))
        let publicKey = TonSwift.PublicKey(data: Data(padded.prefix(32)))
        return Wallet(
            id: "perps-section-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Perps Section", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}
