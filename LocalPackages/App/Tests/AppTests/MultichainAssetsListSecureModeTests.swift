@testable import App
import BigInt
@testable import KeeperCore
import TKUIKit
import TonSwift
import XCTest

@MainActor
final class MultichainAssetsListSecureModeTests: XCTestCase {
    func test_loadedAndLocallyUpdatedPortfolioTotalsKeepBalanceFilterCacheKey() async throws {
        let update = makeVisibilityUpdate()
        let context = makeContext(
            isSecureMode: false,
            hidesDustBalances: true,
            walletAssetsPage: MultichainWalletAssetsPage(
                assets: update.visibleAssets,
                nextCursor: nil,
                fiatPrice: ["usd": "7"]
            )
        )

        await context.viewModel.loadAssets()
        await waitUntil {
            context.portfolioStore.getState()[context.wallet]?.fiatPrice["usd"] == "7"
        }

        var total = try XCTUnwrap(context.portfolioStore.getState()[context.wallet])
        XCTAssertTrue(total.hidesDustBalances)

        context.viewModel.applyVisibilityUpdate(update)
        await waitUntil {
            context.portfolioStore.getState()[context.wallet]?.fiatPrice["usd"] == "3"
        }

        total = try XCTUnwrap(context.portfolioStore.getState()[context.wallet])
        XCTAssertTrue(total.hidesDustBalances)
    }

    func test_visibilityUpdateSkippedWhenFiltersDivergeFromLoadedList() {
        // Dust filter is on in settings, but the loaded list still reflects dust=off (the filtered
        // reload hasn't landed). The optimistic delta must be skipped so it can't write a
        // pre-filter list/total; reloadAssetsList refetches under the current filters instead.
        let context = makeContext(isSecureMode: false, hidesDustBalances: true)

        context.viewModel.applyVisibilityUpdate(makeVisibilityUpdate())

        XCTAssertEqual(context.viewModel.presentation, .rows([]))
        XCTAssertNil(context.portfolioStore.getState()[context.wallet])
    }

    func test_rowShowsAmountsWhenSecureModeIsOff() {
        let context = makeContext(isSecureMode: false)

        context.viewModel.applyVisibilityUpdate(makeVisibilityUpdate())

        let amounts = try? XCTUnwrap(amounts(in: context.viewModel))
        XCTAssertEqual(amounts?.balance, "1.5")
        XCTAssertEqual(amounts?.fiat, "$\u{2009}3")
    }

    func test_rowMasksBalanceAndFiatInSecureMode() {
        let context = makeContext(isSecureMode: true)

        context.viewModel.applyVisibilityUpdate(makeVisibilityUpdate())

        let amounts = try? XCTUnwrap(amounts(in: context.viewModel))
        XCTAssertEqual(amounts?.balance, String.secureModeValueShort)
        XCTAssertEqual(amounts?.fiat, String.secureModeValueShort)
    }

    /// The unit price is market data, not a balance, so hiding it would leave the row unreadable.
    func test_rowKeepsUnitPriceInSecureMode() {
        let context = makeContext(isSecureMode: true)

        context.viewModel.applyVisibilityUpdate(makeVisibilityUpdate())

        let amounts = try? XCTUnwrap(amounts(in: context.viewModel))
        XCTAssertEqual(amounts?.price, "$\u{2009}2")
    }

    func test_togglingSecureModeRebuildsAlreadyLoadedRows() async {
        let context = makeContext(isSecureMode: false)
        context.viewModel.applyVisibilityUpdate(makeVisibilityUpdate())

        await toggleSecureMode(context.appSettingsStore)

        await waitUntil {
            await MainActor.run {
                self.amounts(in: context.viewModel)?.balance == String.secureModeValueShort
            }
        }
    }

    func test_persistedPortfolioRendersRowsBeforeAnyRequest() {
        let cached = makeAsset()
        let context = makeContext(
            isSecureMode: false,
            cachedPortfolio: makeCachedPortfolio(assets: [cached])
        )

        let restored = context.viewModel.restoreCachedAssets()

        XCTAssertTrue(restored)
        XCTAssertEqual(rowIDs(in: context.viewModel), [cached.asset.assetId])
        XCTAssertEqual(amounts(in: context.viewModel)?.fiat, "$\u{2009}3")
    }

    func test_failedRefreshKeepsRestoredRowsWithoutErrorPlaceholder() async {
        let cached = makeAsset()
        let context = makeContext(
            isSecureMode: false,
            cachedPortfolio: makeCachedPortfolio(assets: [cached])
        )
        context.viewModel.restoreCachedAssets()

        await context.viewModel.loadAssets()

        XCTAssertNotEqual(context.viewModel.presentation, .error)
        XCTAssertEqual(rowIDs(in: context.viewModel), [cached.asset.assetId])
    }

    func test_networkResultReplacesRestoredRows() async {
        let cached = makeAsset(assetId: "eth/mainnet/erc20/0xcached", symbol: "OLD")
        let fresh = makeAsset()
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(assets: [fresh], nextCursor: nil, fiatPrice: ["usd": "3"]),
            cachedPortfolio: makeCachedPortfolio(assets: [cached])
        )
        context.viewModel.restoreCachedAssets()

        await context.viewModel.loadAssets()

        XCTAssertEqual(rowIDs(in: context.viewModel), [fresh.asset.assetId])
    }

    func test_restoreDoesNotReplaceAnAnsweredList() async {
        let cached = makeAsset(assetId: "eth/mainnet/erc20/0xcached", symbol: "OLD")
        let fresh = makeAsset()
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(assets: [fresh], nextCursor: nil, fiatPrice: ["usd": "3"]),
            cachedPortfolio: makeCachedPortfolio(assets: [cached])
        )
        await context.viewModel.loadAssets()

        XCTAssertFalse(context.viewModel.restoreCachedAssets())
        XCTAssertEqual(rowIDs(in: context.viewModel), [fresh.asset.assetId])
    }

    func test_persistedPortfolioForAnotherAccountSetIsIgnored() {
        let context = makeContext(
            isSecureMode: false,
            cachedPortfolio: makeCachedPortfolio(assets: [makeAsset()], accountsIdentifier: "other-accounts")
        )

        XCTAssertFalse(context.viewModel.restoreCachedAssets())
        XCTAssertEqual(context.viewModel.presentation, .rows([]))
    }

    func test_persistedPortfolioUnderAnotherDustFilterIsIgnored() {
        let context = makeContext(
            isSecureMode: false,
            cachedPortfolio: makeCachedPortfolio(assets: [makeAsset()], hidesDustBalances: true)
        )

        XCTAssertFalse(context.viewModel.restoreCachedAssets())
        XCTAssertEqual(context.viewModel.presentation, .rows([]))
    }

    func test_persistedPortfolioInAnotherCurrencyIsIgnored() {
        let context = makeContext(
            isSecureMode: false,
            cachedPortfolio: makeCachedPortfolio(assets: [makeAsset()], currencyCode: "eur")
        )

        XCTAssertFalse(context.viewModel.restoreCachedAssets())
        XCTAssertEqual(context.viewModel.presentation, .rows([]))
    }

    func test_loadPersistsAssetsWithTotalAndScope() async throws {
        let asset = makeAsset()
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(assets: [asset], nextCursor: nil, fiatPrice: ["usd": "3"])
        )

        await context.viewModel.loadAssets()
        await waitUntil {
            context.portfolioStore.getState()[context.wallet] != nil
        }

        let portfolio = try XCTUnwrap(context.portfolioStore.getState()[context.wallet])
        XCTAssertEqual(portfolio.assets, [asset])
        XCTAssertEqual(portfolio.fiatPrice, ["usd": "3"])
        XCTAssertEqual(portfolio.accountsIdentifier, "multichain-wallet")
        XCTAssertEqual(portfolio.currencyCode, "usd")
        XCTAssertFalse(portfolio.hidesDustBalances)
    }

    func test_visibilityUpdatePersistsAssetDelta() async throws {
        let update = makeVisibilityUpdate()
        let cached = makeAsset(assetId: "eth/mainnet/erc20/0xcached", symbol: "OLD")
        let context = makeContext(
            isSecureMode: false,
            cachedPortfolio: makeCachedPortfolio(assets: [cached])
        )
        context.viewModel.restoreCachedAssets()

        context.viewModel.applyVisibilityUpdate(update)
        await waitUntil {
            context.portfolioStore.getState()[context.wallet]?.assets.count == 2
        }

        let portfolio = try XCTUnwrap(context.portfolioStore.getState()[context.wallet])
        XCTAssertEqual(portfolio.assets, [cached] + update.visibleAssets)
    }
}

private extension MultichainAssetsListSecureModeTests {
    struct Context {
        let viewModel: WalletBalanceMultichainAssetsListViewModel
        let appSettingsStore: AppSettingsStore
        let portfolioStore: MultichainPortfolioStore
        let wallet: Wallet
    }

    func makeContext(
        isSecureMode: Bool,
        hidesDustBalances: Bool = false,
        walletAssetsPage: MultichainWalletAssetsPage? = nil,
        cachedPortfolio: MultichainPortfolio? = nil
    ) -> Context {
        let keeperInfoStore = KeeperInfoStore(
            keeperInfoRepository: KeeperInfoRepositoryStub(
                keeperInfo: makeKeeperInfo(
                    isSecureMode: isSecureMode,
                    hidesDustBalances: hidesDustBalances
                )
            )
        )
        let wallet = keeperInfoStore.getState()!.currentWallet
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)
        let currencyStore = CurrencyStore(keeperInfoStore: keeperInfoStore)
        let appSettingsStore = AppSettingsStore(keeperInfoStore: keeperInfoStore)
        let multichainService = MultichainServiceStub(walletAssetsPage: walletAssetsPage)
        let portfolioStore = MultichainPortfolioStore(
            walletsStore: walletsStore,
            repository: MultichainAssetsListPortfolioRepositoryStub(
                portfolios: cachedPortfolio.map { [makeWallet().id: $0] } ?? [:]
            )
        )
        let stakingPoolsStore = StakingPoolsStore(
            walletsStore: walletsStore,
            repository: StakingPoolsInfoRepositoryStub()
        )

        let viewModel = WalletBalanceMultichainAssetsListViewModel(
            wallet: wallet,
            multichainService: multichainService,
            multichainAssetBalanceProvider: MultichainAssetBalanceProvider(
                balanceService: multichainService,
                currencyStore: currencyStore
            ),
            currencyStore: currencyStore,
            amountFormatter: makeAmountFormatter(),
            portfolioStore: portfolioStore,
            stakingPoolsStore: stakingPoolsStore,
            processedBalanceStore: ProcessedBalanceStore(
                walletsStore: walletsStore,
                balanceStore: BalanceStore(
                    walletsStore: walletsStore,
                    repository: WalletBalanceRepositoryStub()
                ),
                tonRatesStore: TonRatesStore(repository: RatesRepositoryStub()),
                currencyStore: currencyStore,
                stakingPoolsStore: stakingPoolsStore
            ),
            appSettingsStore: appSettingsStore,
            tonStakingAPYProvider: { _ in nil },
            tonStakingAPYTextFormatter: { _ in nil },
            canManage: true
        )

        return Context(
            viewModel: viewModel,
            appSettingsStore: appSettingsStore,
            portfolioStore: portfolioStore,
            wallet: wallet
        )
    }

    func makeVisibilityUpdate() -> TokenManagementVisibilityUpdate {
        let asset = makeAsset()

        return TokenManagementVisibilityUpdate(
            changes: [
                MultichainAssetFilterChange(assetId: asset.asset.assetId, action: .show),
            ],
            visibleAssets: [asset]
        )
    }

    func makeAsset(
        assetId: String = "eth/mainnet/erc20/0xdAC17F95",
        symbol: String = "USDT"
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: "Tether USD",
                symbol: symbol,
                decimals: 6,
                image: "",
                verification: .trusted
            ),
            price: MultichainAssetPrice(
                prices: ["USD": 2, "usd": 2],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            ),
            balance: BigUInt(1_500_000)
        )
    }

    /// Scope defaults match `makeWallet()` and a `makeContext` with dust off and USD display.
    func makeCachedPortfolio(
        assets: [MultichainAsset],
        accountsIdentifier: String = "multichain-wallet",
        currencyCode: String = "usd",
        hidesDustBalances: Bool = false
    ) -> MultichainPortfolio {
        MultichainPortfolio(
            fiatPrice: ["usd": "3"],
            assets: assets,
            accountsIdentifier: accountsIdentifier,
            currencyCode: currencyCode,
            hidesDustBalances: hidesDustBalances
        )
    }

    func rowIDs(in viewModel: WalletBalanceMultichainAssetsListViewModel) -> [String]? {
        guard case let .rows(rows) = viewModel.presentation else { return nil }
        return rows.map(\.id)
    }

    func amounts(
        in viewModel: WalletBalanceMultichainAssetsListViewModel
    ) -> (balance: String, price: String, fiat: String)? {
        guard case let .rows(rows) = viewModel.presentation else { return nil }
        let row = rows.compactMap { row -> AssetBalanceRowCellContent? in
            guard case let .asset(content) = row else { return nil }
            return content
        }.first
        guard case let .includingDiffs(balance, price, _, fiat, _, _) = row?.displayMode else {
            return nil
        }
        return (balance, price, fiat)
    }

    func toggleSecureMode(_ appSettingsStore: AppSettingsStore) async {
        await withCheckedContinuation { continuation in
            appSettingsStore.toggleIsSecureMode { _ in
                continuation.resume()
            }
        }
    }

    func makeKeeperInfo(
        isSecureMode: Bool,
        hidesDustBalances: Bool
    ) -> KeeperInfo {
        let wallet = makeWallet()
        return KeeperInfo(
            wallets: [wallet],
            currentWallet: wallet,
            currency: .defaultCurrency,
            securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
            appSettings: KeeperInfo.AppSettings(
                isSecureMode: isSecureMode,
                searchEngine: .duckduckgo,
                hidesDustBalances: hidesDustBalances
            ),
            country: .auto
        )
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
                    .v4R2
                )
            ),
            metaData: WalletMetaData(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(walletId: "multichain-wallet", addresses: [])
            )
        )
    }

    func makeAmountFormatter() -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
    }

    func waitUntil(
        timeout: TimeInterval = 2,
        intervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }

        XCTFail("Timed out waiting for condition")
    }
}

private struct StubError: Error {}

private struct KeeperInfoRepositoryStub: KeeperInfoRepository {
    final class Storage {
        var keeperInfo: KeeperInfo?

        init(keeperInfo: KeeperInfo?) {
            self.keeperInfo = keeperInfo
        }
    }

    private let storage: Storage

    init(keeperInfo: KeeperInfo?) {
        storage = Storage(keeperInfo: keeperInfo)
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo = storage.keeperInfo else {
            throw StubError()
        }
        return keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        storage.keeperInfo = keeperInfo
    }

    func removeKeeperInfo() throws {
        storage.keeperInfo = nil
    }
}

private struct WalletBalanceRepositoryStub: WalletBalanceRepositoryV2 {
    func getBalance(address _: FriendlyAddress) throws -> KeeperCore.WalletBalance {
        throw StubError()
    }
}

private struct RatesRepositoryStub: RatesRepository {
    func saveRates(_: Rates) throws {}

    func getRates() throws -> Rates {
        throw StubError()
    }
}

private struct StakingPoolsInfoRepositoryStub: StakingPoolsInfoRepository {
    func getStakingPoolsInfo(wallet _: Wallet) -> [StackingPoolInfo] {
        []
    }

    func setStakingPoolsInfo(_: [StackingPoolInfo], wallet _: Wallet) throws {}
}

private struct MultichainServiceStub: MultichainService {
    let walletAssetsPage: MultichainWalletAssetsPage?

    init(walletAssetsPage: MultichainWalletAssetsPage? = nil) {
        self.walletAssetsPage = walletAssetsPage
    }

    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth {
        throw .apiError(message: "Unimplemented")
    }

    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?) {
        throw .apiError(message: "Unimplemented")
    }

    func getWallet(walletId _: String) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletSyncStatus(walletId _: String) async throws(MultichainServiceError) -> MultichainWalletSyncStatus {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletAssets(
        state _: MultichainWalletState,
        currencies _: [String],
        assetIds _: [String]?,
        capabilities _: [MultichainAssetCapability]?,
        chain _: MultichainChain?,
        search _: String?,
        availableOnly _: Bool?,
        showHidden _: Bool?,
        hideDust _: Bool?,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        throw .apiError(message: "Unimplemented")
    }

    func getAllWalletAssets(
        state _: MultichainWalletState,
        currencies _: [String],
        capabilities _: [MultichainAssetCapability]?,
        chain _: MultichainChain?,
        search _: String?,
        availableOnly _: Bool?,
        showHidden _: Bool?,
        hideDust _: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        if let walletAssetsPage {
            return walletAssetsPage
        }
        throw .apiError(message: "Unimplemented")
    }

    func saveWalletAssetsFilters(
        walletId _: String,
        changes _: [MultichainAssetFilterChange]
    ) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletActivities(
        state _: MultichainWalletState,
        limit _: Int?,
        cursor _: String?,
        chain _: MultichainChain?,
        assetId _: String?,
        activityTypeFilter _: MultichainActivityTypeFilter?,
        showPerps _: Bool?,
        hideDust _: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletChallenge() async throws(MultichainServiceError) -> MultichainWalletChallenge {
        throw .apiError(message: "Unimplemented")
    }

    func broadcastTx(
        chain _: MultichainChain,
        signedTransaction _: Data
    ) async throws(MultichainServiceError) -> MultichainBroadcastResult {
        throw .apiError(message: "Unimplemented")
    }

    func getFees(chain _: MultichainChain) async throws(MultichainServiceError) -> MultichainFeeEstimate {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletRaffles(
        walletId _: String,
        lang _: String?,
        ids _: [String]?,
        debugNow _: Date?,
        isNewUser _: Bool
    ) async throws(MultichainServiceError) -> [MultichainRaffle] {
        throw .apiError(message: "Unimplemented")
    }

    func completeRaffleMigration(walletId _: String) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func markRaffleImport(walletId _: String, importedWalletId _: String) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func forcePickRaffleWinners(
        raffleId _: String,
        walletId _: String?,
        prizeId _: String?
    ) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }
}

private final class MultichainAssetsListPortfolioRepositoryStub: MultichainPortfolioRepository {
    private enum Error: Swift.Error {
        case noPortfolio
    }

    private var portfolios: [String: MultichainPortfolio]

    init(portfolios: [String: MultichainPortfolio] = [:]) {
        self.portfolios = portfolios
    }

    func getPortfolio(walletId: String) throws -> MultichainPortfolio {
        guard let portfolio = portfolios[walletId] else {
            throw Error.noPortfolio
        }
        return portfolio
    }

    func savePortfolio(_ portfolio: MultichainPortfolio, walletId: String) throws {
        portfolios[walletId] = portfolio
    }
}
