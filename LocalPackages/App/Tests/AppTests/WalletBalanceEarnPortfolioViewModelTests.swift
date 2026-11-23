@testable import App
import AppUI
@testable import KeeperCore
import KeeperCoreComponents
import TKCore
import TKTestSupport
import TonSwift
import XCTest

@MainActor
final class WalletBalanceEarnPortfolioViewModelTests: XCTestCase {
    private var directory: URL!
    private var analytics: AnalyticsServiceSpy!
    private var balanceLoader: BalanceLoaderSpy!
    private var store: EarnPortfolioStore!
    private var appSettingsStore: AppSettingsStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WalletBalanceEarnPortfolioViewModelTests-\(UUID().uuidString)")
        analytics = AnalyticsServiceSpy()
        balanceLoader = BalanceLoaderSpy()
        store = makeStore()
        appSettingsStore = AppSettingsStore(
            keeperInfoStore: KeeperInfoStore(keeperInfoRepository: KeeperInfoRepositoryStub(wallet: wallet))
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func test_walletWithoutAMultichainWalletHasNoPortfolio() {
        let viewModel = makeViewModel(wallet: makeWallet(multichainWalletId: nil))

        XCTAssertEqual(viewModel.state, .disabled)
    }

    func test_walletNotSyncedYetHasNoPortfolio() {
        let viewModel = makeViewModel(wallet: makeWallet(multichainWalletId: multichainWalletId, syncState: .pending))

        XCTAssertEqual(viewModel.state, .disabled)
    }

    func test_disabledEarnHidesEvenACachedPortfolio() async {
        await store.setPortfolio(portfolio, wallet: wallet)

        let viewModel = makeViewModel(isEnabled: false)

        XCTAssertEqual(viewModel.state, .disabled)
    }

    func test_nothingAnsweredYetIsLoading() {
        XCTAssertEqual(makeViewModel().state, .loading)
    }

    func test_cachedPortfolioShowsAtOnce() async {
        await store.setPortfolio(portfolio, wallet: wallet)

        let viewModel = makeViewModel(store: makeStore())

        XCTAssertEqual(viewModel.state, .positions(section(isStale: false)))
    }

    func test_answerForTheWalletIsShown() async {
        let viewModel = makeViewModel()

        await store.setPortfolio(portfolio, wallet: wallet)

        await waitUntil(viewModel) { viewModel.state != .loading }
        XCTAssertEqual(viewModel.state, .positions(section(isStale: false)))
    }

    func test_answerWithoutPositionsIsEmpty() async {
        let viewModel = makeViewModel()

        await store.setPortfolio(
            EarnPortfolio(walletId: multichainWalletId, totalFiat: ["USD": 0], positions: []),
            wallet: wallet
        )

        await waitUntil(viewModel) { viewModel.state != .loading }
        XCTAssertEqual(viewModel.state, .empty)
    }

    func test_failedRefreshKeepsThePositionsMarkedStale() async {
        await store.setPortfolio(portfolio, wallet: wallet)
        let viewModel = makeViewModel()

        await store.setLoadFailed(wallet: wallet)

        await waitUntil(viewModel) { viewModel.state == .positions(self.section(isStale: true)) }
    }

    func test_failureWithNothingToFallBackOnIsUnavailable() async {
        let viewModel = makeViewModel()

        await store.setLoadFailed(wallet: wallet)

        await waitUntil(viewModel) { viewModel.state == .unavailable }
    }

    func test_retryAsksForTheWalletBalanceAsTheUser() async {
        let viewModel = makeViewModel()

        viewModel.reload()

        await waitUntil(balanceLoader.changes) { self.balanceLoader.reloads.count == 1 }
        XCTAssertEqual(balanceLoader.reloads.first?.wallet, wallet)
        XCTAssertEqual(balanceLoader.reloads.first?.priority, .userInitiated)
    }

    func test_walletFinishingItsSyncAsksForARunAfterTheOneInFlight() async {
        let viewModel = makeViewModel(wallet: makeWallet(multichainWalletId: multichainWalletId, syncState: .pending))

        viewModel.adopt(wallet: wallet)

        XCTAssertEqual(viewModel.state, .loading)
        await waitUntil(balanceLoader.changes) { self.balanceLoader.reloads.count == 1 }
        XCTAssertEqual(balanceLoader.reloads.first?.wallet, wallet)
        XCTAssertEqual(balanceLoader.reloads.first?.priority, .background)
    }

    func test_adoptingAnUnchangedWalletAsksNothing() async {
        let viewModel = makeViewModel()

        viewModel.adopt(wallet: wallet)
        viewModel.reload()

        await waitUntil(balanceLoader.changes) { !self.balanceLoader.reloads.isEmpty }
        XCTAssertEqual(balanceLoader.reloads.map(\.priority), [.userInitiated])
    }

    func test_secureModeHidesTheAmountsAsItTurnsOn() async {
        await store.setPortfolio(portfolio, wallet: wallet)
        let viewModel = makeViewModel()

        appSettingsStore.toggleIsSecureMode()

        await waitUntil(viewModel) { viewModel.state == .positions(self.section(total: "* * *", isStale: false)) }
    }

    func test_shownPositionsAreReportedOncePerAppearance() async {
        await store.setPortfolio(portfolio, wallet: wallet)
        let viewModel = makeViewModel()

        viewModel.positionsDidAppear()
        viewModel.positionsDidAppear()
        viewModel.positionsDidDisappear()
        viewModel.positionsDidAppear()

        XCTAssertEqual(analytics.events.map(\.name), ["earn_entry_view", "earn_entry_view"])
        let args = analytics.events.first?.args
        XCTAssertEqual(args?["from"] as? String, "earn_your_vaults")
        XCTAssertEqual(args?["vaults_count"] as? Int, 1)
        XCTAssertEqual(args?["balance_usd"] as? Double, 0.2002)
    }

    func test_emptyPortfolioIsNotReportedAsTheBlockOfVaults() async {
        await store.setPortfolio(
            EarnPortfolio(walletId: multichainWalletId, totalFiat: ["USD": 0], positions: []),
            wallet: wallet
        )
        let viewModel = makeViewModel()

        viewModel.positionsDidAppear()

        XCTAssertTrue(analytics.events.isEmpty)
    }

    func test_selectingARowReportsItsPosition() async {
        await store.setPortfolio(portfolio, wallet: wallet)
        let viewModel = makeViewModel()
        var selected: EarnPosition?
        viewModel.onSelectPosition = { selected = $0 }

        viewModel.selectRow(id: "mainnet/0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c")

        XCTAssertEqual(selected, portfolio.positions.first)
    }
}

private extension WalletBalanceEarnPortfolioViewModelTests {
    var multichainWalletId: String {
        "aiabcdefghijklmnopqrstuvwxyz2345672"
    }

    var wallet: Wallet {
        makeWallet(multichainWalletId: multichainWalletId)
    }

    var portfolio: EarnPortfolio {
        EarnPortfolio(
            walletId: multichainWalletId,
            totalFiat: ["USD": Decimal(string: "0.2002")!],
            positions: [
                EarnPosition(
                    network: "mainnet",
                    vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
                    protocolName: "Aave",
                    assetSymbol: "USDC",
                    assetIconURL: nil,
                    balanceFiat: ["USD": Decimal(string: "0.2002")!],
                    earnedFiat: ["USD": Decimal(string: "0.000239")!]
                ),
            ]
        )
    }

    func section(total: String = "0.2002", isStale: Bool) -> EarnPortfolioSectionState {
        EarnPortfolioSectionState(totalBalance: total, isStale: isStale, rows: [])
    }

    func makeWallet(multichainWalletId: String?, syncState: MultichainWalletSyncState = .synced) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: multichainWalletId ?? "",
                    addresses: multichainWalletId == nil
                        ? []
                        : [MultichainWalletAddress(chain: .eth, address: "0x7ecebaf27c989adef9ea3dd06d316f6f463a5109")],
                    syncState: syncState
                )
            )
        )
    }

    func makeStore() -> EarnPortfolioStore {
        EarnPortfolioStore(
            walletsStore: WalletsStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: KeeperInfoRepositoryStub(wallet: wallet)
                )
            ),
            repository: EarnPortfolioRepository(
                fileSystemVault: FileSystemVault(fileManager: .default, directory: directory)
            )
        )
    }

    func makeViewModel(
        wallet: Wallet? = nil,
        isEnabled: Bool = true,
        store: EarnPortfolioStore? = nil
    ) -> WalletBalanceEarnPortfolioViewModel {
        WalletBalanceEarnPortfolioViewModel(
            wallet: wallet ?? self.wallet,
            isEnabled: isEnabled,
            store: store ?? self.store,
            balanceLoader: balanceLoader,
            appSettingsStore: appSettingsStore,
            mapper: { [appSettingsStore] portfolio, isStale in
                EarnPortfolioSectionState(
                    totalBalance: appSettingsStore?.getState().isSecureMode == true
                        ? "* * *"
                        : "\(portfolio.totalFiat["USD"] ?? 0)",
                    isStale: isStale,
                    rows: []
                )
            },
            analyticsProvider: AnalyticsProvider(
                analyticsServices: [analytics],
                uniqueIdProvider: coreAssembly.uniqueIdProvider,
                appInfoProvider: coreAssembly.appInfoProvider,
                keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
            ),
            limitModel: WalletSectionLimitModel(limit: .initial) { _ in }
        )
    }

    var coreAssembly: TKCore.CoreAssembly {
        TKCore.CoreAssembly()
    }
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var events = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        events.append((name: name, args: args))
    }
}

private final class BalanceLoaderSpy: BalanceLoader {
    private(set) var reloads = [(wallet: Wallet, priority: BalanceRefreshPriority)]()
    let changes = TestSignal()

    func reloadBalance(wallet: Wallet, priority: BalanceRefreshPriority) async -> BalanceRefreshResult {
        reloads.append((wallet: wallet, priority: priority))
        changes.send()
        return .dropped
    }

    func reloadAllWalletsBalance(priority _: BalanceRefreshPriority) async {}

    func setQuiet(_: Bool, owner _: BalanceQuietOwner) {}

    func setRegularPollingPaused(_: Bool) {}

    func setIsRealtimeSubscribed(_: @escaping @Sendable (String) -> Bool) {}

    func addUpdateObserver<T: AnyObject>(_: T, closure _: @escaping (T, BalanceLoaderUpdate) -> Void) {}
}

private struct KeeperInfoRepositoryStub: KeeperInfoRepository {
    let wallet: Wallet

    func getKeeperInfo() throws -> KeeperInfo {
        KeeperInfo(
            wallets: [wallet],
            currentWallet: wallet,
            currency: .defaultCurrency,
            securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
            appSettings: KeeperInfo.AppSettings(
                isSecureMode: false,
                searchEngine: .duckduckgo,
                hidesDustBalances: false
            ),
            country: .auto
        )
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
