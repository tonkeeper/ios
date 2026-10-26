@testable import App
import Combine
@testable import KeeperCore
@testable import Perps
import PerpsModels
import TonSwift
import XCTest

final class TradeAssetDetailsPerpPositionViewModelTests: XCTestCase {
    @MainActor
    func test_openPositionOnTheAssetMarket_showsThePositionRow() async {
        let reader = PerpPositionAccountReaderStub()
        reader.statusResult = .account(accountIndex: 7)
        reader.portfolioResult = PerpsAccountSnapshot(
            availableBalance: "100",
            positions: [.test(marketId: 3, symbol: "GRAM", marginUsd: 20, unrealizedPnlUsd: 0.5)]
        )
        let viewModel = makeViewModel(reader: reader)

        await expectState(viewModel, description: "position shown") {
            if case let .position(row) = $0 { return row.id == 3 }
            return false
        }
        guard case let .position(row) = viewModel.state else { return XCTFail("expected position") }
        XCTAssertEqual(row.valueText, PerpsFormatting.live.usd(20.5))
        viewModel.didDisappear()
    }

    @MainActor
    func test_positionOnlyOnAnotherMarket_showsTheBanner() async {
        let reader = PerpPositionAccountReaderStub()
        reader.statusResult = .account(accountIndex: 7)
        reader.portfolioResult = PerpsAccountSnapshot(
            availableBalance: "100",
            positions: [.test(marketId: 1, symbol: "BTC")]
        )
        let viewModel = makeViewModel(reader: reader)

        await expectState(viewModel, description: "banner shown") { $0 == .noPosition }
        viewModel.didDisappear()
    }

    @MainActor
    func test_walletWithoutPerpsAccount_showsTheBanner() async {
        let reader = PerpPositionAccountReaderStub()
        reader.statusResult = .unbound
        let viewModel = makeViewModel(reader: reader)

        await expectState(viewModel, description: "banner shown") { $0 == .noPosition }
        viewModel.didDisappear()
    }

    @MainActor
    func test_coldStoreOpenedByDeeplink_showsThePositionWithoutABannerFirst() async {
        let reader = PerpPositionAccountReaderStub()
        reader.statusResult = .account(accountIndex: 7)
        reader.portfolioResult = PerpsAccountSnapshot(
            availableBalance: "100",
            positions: [.test(marketId: 3, symbol: "ETH")]
        )
        reader.portfolioDelayNanoseconds = 100_000_000
        let viewModel = TradeAssetDetailsPerpPositionViewModel(
            accountStore: PerpsAccountStore(service: reader, wallet: .perpPositionTest())
        )
        var states: [TradeAssetDetailsPerpPositionViewModel.State] = []
        let shown = expectation(description: "position shown")
        let cancellable = viewModel.$state.sink { state in
            states.append(state)
            if case .position = state { shown.fulfill() }
        }

        viewModel.didAppear()
        viewModel.setMarket(3, iconURL: nil)
        await fulfillment(of: [shown], timeout: 2)

        XCTAssertTrue(states.contains(.loading))
        XCTAssertFalse(states.contains(.noPosition))
        withExtendedLifetime(cancellable) {}
        viewModel.didDisappear()
    }

    @MainActor
    func test_assetWithoutPerpMarket_doesNoPerpsWork() async {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)

        viewModel.didAppear()
        viewModel.setMarket(nil, iconURL: nil)
        store.notify()
        await settle()

        XCTAssertEqual(viewModel.state, .unknown)
        XCTAssertEqual(store.resolveCount, 0)
        XCTAssertEqual(store.subscribeCount, 0)
    }

    @MainActor
    func test_pollsPositionsOnlyWhileOnScreen() {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)

        viewModel.setMarket(3, iconURL: nil)
        XCTAssertEqual(store.resolveCount, 0)
        XCTAssertEqual(store.subscribeCount, 0)

        viewModel.didAppear()
        viewModel.didAppear()
        XCTAssertEqual(store.resolveCount, 1)
        XCTAssertEqual(store.subscribeCount, 1)

        viewModel.didDisappear()
        viewModel.didDisappear()
        XCTAssertEqual(store.unsubscribeCount, 1)

        viewModel.didAppear()
        viewModel.didDisappear()
        XCTAssertEqual(store.subscribeCount, 2)
        XCTAssertEqual(store.unsubscribeCount, 2)
    }

    @MainActor
    func test_releasingTheOpenPage_stopsPolling() {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        weak var released: TradeAssetDetailsPerpPositionViewModel?
        do {
            let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)
            released = viewModel
            viewModel.didAppear()
            viewModel.setMarket(3, iconURL: nil)
            XCTAssertEqual(store.subscribeCount, 1)
        }

        XCTAssertNil(released)
        XCTAssertEqual(store.unsubscribeCount, 1)
    }

    @MainActor
    func test_accountLosingPerps_stopsPollingAndShowsTheBanner() async {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)
        viewModel.didAppear()
        viewModel.setMarket(3, iconURL: nil)

        store.state = .inactive
        store.notify()
        await settle()

        XCTAssertEqual(viewModel.state, .noPosition)
        XCTAssertEqual(store.unsubscribeCount, 1)
    }

    @MainActor
    func test_positionClosedElsewhere_switchesToTheBanner() async {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)
        viewModel.didAppear()
        viewModel.setMarket(3, iconURL: nil)
        guard case .position = viewModel.state else { return XCTFail("expected position") }

        store.state = .active(PerpsAccount(accountIndex: 7, availableBalance: "100"))
        store.notify()
        await settle()

        XCTAssertEqual(viewModel.state, .noPosition)
    }

    @MainActor
    func test_reresolvingAccount_keepsTheShownPosition() async {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)
        viewModel.didAppear()
        viewModel.setMarket(3, iconURL: nil)
        let shown = viewModel.state
        guard case .position = shown else { return XCTFail("expected position") }

        store.state = .unresolved
        store.notify()
        await settle()

        XCTAssertEqual(viewModel.state, shown)
    }

    @MainActor
    func test_pageRefresh_reloadsAnActiveAccount() {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)
        viewModel.setMarket(3, iconURL: nil)
        viewModel.didAppear()
        let resolveCount = store.resolveCount

        viewModel.refresh()

        XCTAssertEqual(store.refreshCount, 1)
        XCTAssertEqual(store.resolveCount, resolveCount)
    }

    @MainActor
    func test_pageRefresh_retriesAnAccountThatIsNotLoaded() {
        let store = PerpPositionAccountStoreStub(state: .unresolved)
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)
        viewModel.setMarket(3, iconURL: nil)
        viewModel.didAppear()
        let resolveCount = store.resolveCount

        viewModel.refresh()

        XCTAssertEqual(store.resolveCount, resolveCount + 1)
        XCTAssertEqual(store.refreshCount, 0)
    }

    @MainActor
    func test_pageRefresh_leavesWalletsWithoutPerpsAccountAndAssetsWithoutMarketAlone() {
        let inactiveStore = PerpPositionAccountStoreStub(state: .inactive)
        let inactiveViewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: inactiveStore)
        inactiveViewModel.setMarket(3, iconURL: nil)
        inactiveViewModel.didAppear()
        let inactiveResolveCount = inactiveStore.resolveCount
        inactiveViewModel.refresh()

        let noMarketStore = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let noMarketViewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: noMarketStore)
        noMarketViewModel.setMarket(nil, iconURL: nil)
        noMarketViewModel.didAppear()
        noMarketViewModel.refresh()

        XCTAssertEqual(inactiveStore.refreshCount, 0)
        XCTAssertEqual(inactiveStore.resolveCount, inactiveResolveCount)
        XCTAssertEqual(noMarketStore.refreshCount + noMarketStore.resolveCount, 0)
    }

    @MainActor
    func test_pageRefreshWhileCovered_waitsForThePageToComeBack() {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)
        viewModel.setMarket(3, iconURL: nil)

        viewModel.refresh()
        viewModel.refresh()
        XCTAssertEqual(store.refreshCount + store.resolveCount, 0)

        viewModel.didAppear()
        XCTAssertEqual(store.refreshCount, 1)
        XCTAssertEqual(store.resolveCount, 0)

        viewModel.didDisappear()
        viewModel.didAppear()
        XCTAssertEqual(store.refreshCount, 1)
    }

    @MainActor
    func test_anotherWalletBecomingActive_hidesTheSectionUntilItsWalletIsBack() async {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)
        viewModel.didAppear()
        viewModel.setMarket(3, iconURL: nil)
        guard case .position = viewModel.state else { return XCTFail("expected position") }
        let resolveCount = store.resolveCount

        viewModel.setWalletActive(false)
        XCTAssertEqual(viewModel.state, .unknown)
        XCTAssertEqual(store.unsubscribeCount, 1)

        viewModel.refresh()
        viewModel.didDisappear()
        viewModel.didAppear()
        store.notify()
        await settle()
        XCTAssertEqual(viewModel.state, .unknown)
        XCTAssertEqual(store.subscribeCount, 1)
        XCTAssertEqual(store.refreshCount, 0)
        XCTAssertEqual(store.resolveCount, resolveCount)

        viewModel.setWalletActive(true)
        guard case .position = viewModel.state else { return XCTFail("expected position") }
        XCTAssertEqual(store.subscribeCount, 2)
    }

    @MainActor
    func test_marketChange_dropsThePreviousMarketsPosition() {
        let store = PerpPositionAccountStoreStub(state: .active(.withPosition(marketId: 3)))
        let viewModel = TradeAssetDetailsPerpPositionViewModel(accountStore: store)
        viewModel.didAppear()
        viewModel.setMarket(3, iconURL: nil)
        guard case .position = viewModel.state else { return XCTFail("expected position") }

        store.state = .unresolved
        viewModel.setMarket(5, iconURL: nil)

        XCTAssertEqual(viewModel.state, .loading)
    }
}

private extension TradeAssetDetailsPerpPositionViewModelTests {
    @MainActor
    func settle() async {
        for _ in 0 ..< 16 {
            await Task.yield()
        }
    }

    @MainActor
    func makeViewModel(reader: PerpPositionAccountReaderStub) -> TradeAssetDetailsPerpPositionViewModel {
        let viewModel = TradeAssetDetailsPerpPositionViewModel(
            accountStore: PerpsAccountStore(service: reader, wallet: .perpPositionTest())
        )
        viewModel.setMarket(3, iconURL: nil)
        return viewModel
    }

    @MainActor
    func expectState(
        _ viewModel: TradeAssetDetailsPerpPositionViewModel,
        description: String,
        matching predicate: @escaping (TradeAssetDetailsPerpPositionViewModel.State) -> Bool
    ) async {
        let published = expectation(description: description)
        var isFulfilled = false
        let cancellable = viewModel.$state.sink { value in
            guard !isFulfilled, predicate(value) else { return }
            isFulfilled = true
            published.fulfill()
        }
        viewModel.didAppear()
        await fulfillment(of: [published], timeout: 2)
        withExtendedLifetime(cancellable) {}
    }
}

private final class PerpPositionAccountStoreStub: PerpsAccountStoring {
    var state: PerpsWalletAccountState
    private(set) var resolveCount = 0
    private(set) var refreshCount = 0
    private(set) var subscribeCount = 0
    private(set) var unsubscribeCount = 0
    private var observers: [() -> Void] = []

    init(state: PerpsWalletAccountState) {
        self.state = state
    }

    func notify() {
        observers.forEach { $0() }
    }

    func addChangeObserver<T: AnyObject>(_ observer: T, onChange: @escaping (T) -> Void) {
        observers.append { [weak observer] in observer.map(onChange) }
    }

    func currentWalletState() -> PerpsWalletAccountState {
        state
    }

    func resolveIfNeeded() {
        resolveCount += 1
    }

    func refresh() {
        refreshCount += 1
    }

    func fundingActivity() -> PerpsFundingActivity {
        PerpsFundingActivity()
    }

    func lifecycle(marketId _: Int64) -> PerpsMarketLifecycle {
        .flat
    }

    func matchingPosition(marketId _: Int64) -> PerpsPositionSummary? {
        nil
    }

    func beginOpening(_: PerpsOpeningDescriptor) {}
    func beginClosing(marketId _: Int64) {}
    func beginAdjusting(marketId _: Int64, direction _: PerpsSizeChangeDirection, baseSizeBefore _: Double) {}
    func beginAdjustingMargin(
        marketId _: Int64,
        direction _: PerpsMarginChangeDirection,
        allocatedMarginBefore _: Double,
        amountUsd _: Double
    ) {}
    func clearPending(marketId _: Int64) {}
    func marketExtras(marketId _: Int64) -> PerpsMarketExtras? {
        nil
    }

    func loadMarketExtras(marketId _: Int64, clearingPending _: Bool) {}
    func releaseMarketExtras(marketId _: Int64) {}
    func subscribePositions(cadence _: PerpsPositionsCadence) {
        subscribeCount += 1
    }

    func unsubscribePositions(cadence _: PerpsPositionsCadence) {
        unsubscribeCount += 1
    }
}

private extension PerpsAccount {
    static func withPosition(marketId: Int64) -> PerpsAccount {
        PerpsAccount(
            accountIndex: 7,
            availableBalance: "100",
            positions: [.test(marketId: marketId, symbol: "GRAM")]
        )
    }
}

private final class PerpPositionAccountReaderStub: PerpsAccountReading, @unchecked Sendable {
    var statusResult: PerpsAccountStatus = .unknown
    var portfolioResult: PerpsAccountSnapshot?
    var portfolioDelayNanoseconds: UInt64 = 0

    func status(wallet _: Wallet) async -> PerpsAccountStatus {
        statusResult
    }

    func portfolio(wallet _: Wallet) async throws -> PerpsAccountSnapshot? {
        if portfolioDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: portfolioDelayNanoseconds)
        }
        return portfolioResult
    }

    func watchPositions(
        wallet _: Wallet,
        pollInterval _: TimeInterval,
        focus _: @escaping @Sendable () -> PerpsWatchFocus,
        onUpdate _: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted _: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        PerpsPositionsWatch {}
    }

    func tradingSnapshot(wallet _: Wallet, marketId _: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
    }
}

private extension Wallet {
    static func perpPositionTest() -> Wallet {
        let raw = Data("perp-position-test-key".utf8)
        let padded = raw + Data(repeating: 0, count: max(0, 32 - raw.count))
        return Wallet(
            id: "perp-position-test",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(padded.prefix(32))), .v4R2)
            ),
            metaData: WalletMetaData(label: "Perp Position", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}
