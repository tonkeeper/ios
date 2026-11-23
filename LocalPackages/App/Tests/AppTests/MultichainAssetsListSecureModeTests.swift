@testable import App
import AppUI
import BigInt
@testable import KeeperCore
import TKTestSupport
import TKUIKit
import TonSwift
import XCTest

@MainActor
final class MultichainAssetsListSecureModeTests: XCTestCase {
    func test_visibilityUpdateLeavesTheLoadedPortfolioUntouched() async {
        let asset = makeAsset()
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(
                assets: [asset],
                nextCursor: nil,
                fiatPrice: ["usd": "7"]
            )
        )

        await context.viewModel.loadAssets()
        await waitUntil(context.portfolioChanges) {
            context.portfolioStore.getState()[context.wallet] != nil
        }
        let loaded = context.portfolioStore.getState()[context.wallet]

        context.viewModel.applyVisibilityUpdate(
            TokenManagementVisibilityUpdate(
                changes: [MultichainAssetFilterChange(assetId: asset.asset.assetId, action: .hide)],
                visibleAssets: []
            )
        )

        XCTAssertEqual(context.viewModel.presentation, .allAssetsHidden)
        let wallet = context.wallet
        let stored: MultichainPortfolio? = await withCheckedContinuation { continuation in
            context.portfolioStore.updateState { _ in nil } completion: { continuation.resume(returning: $0[wallet]) }
        }
        XCTAssertEqual(stored, loaded)
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

        await waitUntil(context.viewModel) {
            self.amounts(in: context.viewModel)?.balance == String.secureModeValueShort
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

    /// The restore builds only the rows the collapsed list shows, so it must look the same as the full list.
    func test_restoredListLooksLikeTheFullCollapsedList() {
        for count in [8, 9, 12] {
            let context = makeContext(
                isSecureMode: false,
                cachedPortfolio: makeCachedPortfolio(assets: makeAssets(count: count))
            )
            context.viewModel.restoreCachedAssets()
            let restored = context.viewModel.presentation

            context.viewModel.refreshPresentation()

            XCTAssertEqual(restored, context.viewModel.presentation, "\(count) assets")
        }
    }

    func test_restoredListShowsTheLimitAndAMoreRow() {
        let assets = makeAssets(count: 12)
        let context = makeContext(
            isSecureMode: false,
            cachedPortfolio: makeCachedPortfolio(assets: assets)
        )

        context.viewModel.restoreCachedAssets()

        XCTAssertEqual(rowIDs(in: context.viewModel), assets.prefix(3).map(\.asset.assetId) + ["more-assets"])
    }

    func test_largerLimitOnRestoredListShowsMoreAssets() {
        let assets = makeAssets(count: 30)
        let context = makeContext(
            isSecureMode: false,
            cachedPortfolio: makeCachedPortfolio(assets: assets)
        )
        context.viewModel.restoreCachedAssets()

        context.viewModel.selectLimit(.top25)

        XCTAssertEqual(rowIDs(in: context.viewModel), assets.prefix(25).map(\.asset.assetId) + ["more-assets"])
    }

    func test_listWithinTheLimitHasNoMoreRow() {
        let assets = makeAssets(count: 12)
        let context = makeContext(
            isSecureMode: false,
            cachedPortfolio: makeCachedPortfolio(assets: assets)
        )
        context.viewModel.restoreCachedAssets()

        context.viewModel.selectLimit(.top25)

        XCTAssertEqual(rowIDs(in: context.viewModel), assets.map(\.asset.assetId))
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
        await waitUntil(context.portfolioChanges) {
            context.portfolioStore.getState()[context.wallet] != nil
        }

        let portfolio = try XCTUnwrap(context.portfolioStore.getState()[context.wallet])
        XCTAssertEqual(portfolio.assets, [asset])
        XCTAssertEqual(portfolio.fiatPrice, ["usd": "3"])
        XCTAssertEqual(portfolio.accountsIdentifier, "multichain-wallet")
        XCTAssertEqual(portfolio.currencyCode, "usd")
        XCTAssertFalse(portfolio.hidesDustBalances)
    }

    func test_startedRequestServesTheNextLoad() async {
        let asset = makeAsset()
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(assets: [asset], nextCursor: nil, fiatPrice: ["usd": "3"])
        )

        context.viewModel.startAssetsRequest()
        context.viewModel.startAssetsRequest()
        await context.viewModel.loadAssets()

        XCTAssertEqual(context.walletAssetsRequests.hideDust, [nil])
        XCTAssertEqual(rowIDs(in: context.viewModel), [asset.asset.assetId])
    }

    func test_firstPageShowsWhileTheRestLoads() async throws {
        let firstPageAssets = makeAssets(count: 10)
        let allAssets = makeAssets(count: 12)
        let collapsedRowIDs = allAssets.prefix(3).map(\.asset.assetId) + ["more-assets"]
        let remainingPages = RemainingPagesGate()
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(assets: allAssets, nextCursor: nil, fiatPrice: ["usd": "5"]),
            firstWalletAssetsPage: MultichainWalletAssetsPage(assets: firstPageAssets, nextCursor: "c1", fiatPrice: ["usd": "5"]),
            remainingPages: remainingPages
        )

        let load = Task { await context.viewModel.loadAssets() }
        await waitUntil(context.portfolioChanges) {
            context.portfolioStore.getState()[context.wallet] != nil
        }

        XCTAssertEqual(rowIDs(in: context.viewModel), collapsedRowIDs)
        let firstPortfolio = try XCTUnwrap(context.portfolioStore.getState()[context.wallet])
        XCTAssertEqual(firstPortfolio.fiatPrice, ["usd": "5"])
        XCTAssertEqual(firstPortfolio.assets.count, firstPageAssets.count)
        XCTAssertNil(try? context.portfolioRepository.getPortfolio(walletId: context.wallet.id))

        remainingPages.open()
        await load.value
        await waitUntil(context.portfolioChanges) {
            context.portfolioStore.getState()[context.wallet]?.assets.count == allAssets.count
        }

        XCTAssertEqual(rowIDs(in: context.viewModel), collapsedRowIDs)
        XCTAssertEqual(try context.portfolioRepository.getPortfolio(walletId: context.wallet.id).assets.count, allAssets.count)
    }

    func test_requestStartedBeforeAFilterChangeIsNotReused() async {
        let asset = makeAsset()
        let dustFilteredAsset = makeAsset(assetId: "eth/mainnet/erc20/0xfiltered", symbol: "BIG")
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(assets: [asset], nextCursor: nil, fiatPrice: ["usd": "3"]),
            dustFilteredWalletAssetsPage: MultichainWalletAssetsPage(
                assets: [dustFilteredAsset],
                nextCursor: nil,
                fiatPrice: ["usd": "3"]
            )
        )

        context.viewModel.startAssetsRequest()
        await withCheckedContinuation { continuation in
            context.appSettingsStore.setHidesDustBalances(true) { _ in continuation.resume() }
        }
        await context.viewModel.loadAssets()

        XCTAssertEqual(rowIDs(in: context.viewModel), [dustFilteredAsset.asset.assetId])
    }

    func test_walletWithoutAnEvmAddressShowsNoEarnOffer() async {
        let asset = makeAsset()
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(assets: [asset], nextCursor: nil, fiatPrice: ["usd": "3"]),
            earnOffers: [makeEarnOffer(assetId: asset.asset.assetId)]
        )

        await context.viewModel.loadAssets()
        await context.viewModel.earnOffersTask?.value

        XCTAssertEqual(apys(in: context.viewModel), [nil])
    }

    func test_evmAddressArrivingLaterShowsTheEarnOffer() async {
        let asset = makeAsset()
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(assets: [asset], nextCursor: nil, fiatPrice: ["usd": "3"]),
            earnOffers: [makeEarnOffer(assetId: asset.asset.assetId)]
        )

        context.viewModel.adopt(wallet: makeWallet(evmAddress: "0x1111111111111111111111111111111111111111"))
        await context.viewModel.loadAssets()
        await context.viewModel.earnOffersTask?.value

        XCTAssertEqual(apys(in: context.viewModel), ["5%"])
    }

    func test_reloadOfTheSameAssetsReusesRecentEarnOffers() async {
        let fixture = makeEarnOffersFixture()

        await fixture.reload()
        await fixture.reload()

        let requests = await fixture.repository.requestCount
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(apys(in: fixture.context.viewModel), ["5%"])
    }

    func test_reloadWhileEarnOffersAreInFlightKeepsTheRequest() async {
        let fixture = makeEarnOffersFixture()

        await fixture.context.viewModel.loadAssets()
        await fixture.reload()

        let requests = await fixture.repository.requestCount
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(apys(in: fixture.context.viewModel), ["5%"])
    }

    func test_staleEarnOffersAreRequestedAgain() async {
        let fixture = makeEarnOffersFixture()

        await fixture.reload()
        fixture.environment.now += 5 * 60
        await fixture.reload()

        let requests = await fixture.repository.requestCount
        XCTAssertEqual(requests, 2)
    }

    func test_failedEarnOffersAreRequestedOnTheNextReload() async {
        let fixture = makeEarnOffersFixture(failingRequests: 1)

        await fixture.reload()
        XCTAssertEqual(apys(in: fixture.context.viewModel), [nil])
        await fixture.reload()

        let requests = await fixture.repository.requestCount
        XCTAssertEqual(requests, 2)
        XCTAssertEqual(apys(in: fixture.context.viewModel), ["5%"])
    }

    func test_evmAddressArrivingAfterALoadRequestsEarnOffers() async {
        let fixture = makeEarnOffersFixture(evmAddress: nil)

        await fixture.reload()
        fixture.context.viewModel.adopt(wallet: makeWallet(evmAddress: "0x1111111111111111111111111111111111111111"))
        await fixture.reload()

        let requests = await fixture.repository.requestCount
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(apys(in: fixture.context.viewModel), ["5%"])
    }

    func test_earnSwitchedOnAfterALoadRequestsOffersAgain() async {
        let fixture = makeEarnOffersFixture()
        fixture.environment.isEarnEnabled = false

        await fixture.reload()
        fixture.environment.isEarnEnabled = true
        await fixture.reload()

        let requests = await fixture.repository.requestCount
        XCTAssertEqual(requests, 2)
    }

    func test_tonstakersStakeShowsAsStakingRow() {
        let context = makeContext(isSecureMode: false, stakingPools: [makeTonstakersPool()])

        context.viewModel.applyVisibilityUpdate(makeTonstakersVisibilityUpdate(balance: 1_000_000_000))

        XCTAssertEqual(rowIDs(in: context.viewModel), ["staking/ton/tonstakers"])
    }

    func test_emptyTonstakersStakeShowsNoStakingRow() {
        let context = makeContext(isSecureMode: false, stakingPools: [makeTonstakersPool()])
        let update = makeTonstakersVisibilityUpdate(balance: 0)

        context.viewModel.applyVisibilityUpdate(update)

        XCTAssertEqual(rowIDs(in: context.viewModel), update.visibleAssets.map(\.asset.assetId))
    }

    func test_emptyTonstakersStakeWithPendingWithdrawKeepsStakingRow() {
        let context = makeContext(
            isSecureMode: false,
            stakingPools: [makeTonstakersPool()],
            legacyBalance: makeTonstakersLegacyBalance(pendingWithdraw: 1_000_000_000)
        )

        context.viewModel.applyVisibilityUpdate(makeTonstakersVisibilityUpdate(balance: 0))

        XCTAssertEqual(rowIDs(in: context.viewModel), ["staking/ton/tonstakers"])
    }
}

private extension MultichainAssetsListSecureModeTests {
    final class Environment {
        var now = Date(timeIntervalSince1970: 0)
        var isEarnEnabled = true
    }

    struct EarnOffersFixture {
        let context: Context
        let repository: EarnAssetOffersRepositorySpy
        let environment: Environment

        @MainActor
        func reload() async {
            await context.viewModel.loadAssets()
            await context.viewModel.earnOffersTask?.value
        }
    }

    func makeEarnOffersFixture(
        evmAddress: String? = "0x1111111111111111111111111111111111111111",
        failingRequests: Int = 0
    ) -> EarnOffersFixture {
        let asset = makeAsset()
        let repository = EarnAssetOffersRepositorySpy(
            offers: [makeEarnOffer(assetId: asset.asset.assetId)],
            failingRequests: failingRequests
        )
        let environment = Environment()
        let context = makeContext(
            isSecureMode: false,
            walletAssetsPage: MultichainWalletAssetsPage(assets: [asset], nextCursor: nil, fiatPrice: ["usd": "3"]),
            earnAssetOffersRepository: repository,
            isEarnEnabled: { environment.isEarnEnabled },
            now: { environment.now }
        )
        if let evmAddress {
            context.viewModel.adopt(wallet: makeWallet(evmAddress: evmAddress))
        }
        return EarnOffersFixture(context: context, repository: repository, environment: environment)
    }

    struct Context {
        let viewModel: WalletBalanceMultichainAssetsListViewModel
        let appSettingsStore: AppSettingsStore
        let portfolioStore: MultichainPortfolioStore
        let portfolioChanges: TestSignal
        let wallet: Wallet
        fileprivate let walletAssetsRequests: WalletAssetsRequestLog
        fileprivate let portfolioRepository: MultichainAssetsListPortfolioRepositoryStub
    }

    func makeContext(
        isSecureMode: Bool,
        hidesDustBalances: Bool = false,
        walletAssetsPage: MultichainWalletAssetsPage? = nil,
        dustFilteredWalletAssetsPage: MultichainWalletAssetsPage? = nil,
        firstWalletAssetsPage: MultichainWalletAssetsPage? = nil,
        remainingPages: RemainingPagesGate = RemainingPagesGate(),
        cachedPortfolio: MultichainPortfolio? = nil,
        earnOffers: [EarnAssetOffer] = [],
        earnAssetOffersRepository: EarnAssetOffersRepository? = nil,
        isEarnEnabled: @escaping () -> Bool = { true },
        now: @escaping () -> Date = Date.init,
        stakingPools: [StackingPoolInfo] = [],
        legacyBalance: KeeperCore.WalletBalance? = nil
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
        let multichainService = MultichainServiceStub(
            walletAssetsPage: walletAssetsPage,
            dustFilteredWalletAssetsPage: dustFilteredWalletAssetsPage,
            firstWalletAssetsPage: firstWalletAssetsPage,
            remainingPages: remainingPages
        )
        let portfolioRepository = MultichainAssetsListPortfolioRepositoryStub(
            portfolios: cachedPortfolio.map { [makeWallet().id: $0] } ?? [:]
        )
        let portfolioStore = MultichainPortfolioStore(
            walletsStore: walletsStore,
            repository: portfolioRepository
        )
        let portfolioChanges = TestSignal()
        portfolioStore.addObserver(self) { _, _ in portfolioChanges.send() }
        let stakingPoolsStore = StakingPoolsStore(
            walletsStore: walletsStore,
            repository: StakingPoolsInfoRepositoryStub(pools: stakingPools)
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
                    repository: WalletBalanceRepositoryStub(balance: legacyBalance)
                ),
                tonRatesStore: TonRatesStore(repository: RatesRepositoryStub()),
                currencyStore: currencyStore,
                stakingPoolsStore: stakingPoolsStore
            ),
            appSettingsStore: appSettingsStore,
            tonStakingAPYProvider: { _ in nil },
            tonStakingAPYTextFormatter: { $0.map { "\($0)%" } },
            earnAssetOffersRepository: earnAssetOffersRepository ?? EarnAssetOffersRepositoryStub(offers: earnOffers),
            isEarnEnabled: isEarnEnabled,
            canManage: true,
            limitModel: WalletSectionLimitModel(limit: .initial) { _ in },
            now: now
        )

        return Context(
            viewModel: viewModel,
            appSettingsStore: appSettingsStore,
            portfolioStore: portfolioStore,
            portfolioChanges: portfolioChanges,
            wallet: wallet,
            walletAssetsRequests: multichainService.walletAssetsRequests,
            portfolioRepository: portfolioRepository
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
                diff7d: [:]
            ),
            balance: BigUInt(1_500_000)
        )
    }

    func makeTonstakersVisibilityUpdate(balance: BigUInt) -> TokenManagementVisibilityUpdate {
        let tsTON = MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "ton/mainnet/jetton/\(JettonMasterAddress.tonstakers.toRaw())",
                name: "Tonstakers TON",
                symbol: "tsTON",
                decimals: 9,
                image: "",
                verification: .trusted
            ),
            price: MultichainAssetPrice(prices: ["USD": 2, "usd": 2], diff24h: [:], diff7d: [:]),
            balance: balance
        )
        return TokenManagementVisibilityUpdate(
            changes: [MultichainAssetFilterChange(assetId: tsTON.asset.assetId, action: .show)],
            visibleAssets: [tsTON]
        )
    }

    func makeTonstakersLegacyBalance(pendingWithdraw: Int64) -> KeeperCore.WalletBalance {
        let tsTON = JettonBalance(
            item: JettonItem(
                jettonInfo: JettonInfo(
                    isTransferable: true,
                    hasCustomPayload: false,
                    address: JettonMasterAddress.tonstakers,
                    fractionDigits: 9,
                    name: "Tonstakers TON",
                    symbol: "tsTON",
                    verification: .whitelist,
                    imageURL: nil
                ),
                walletAddress: nil
            ),
            quantity: 0,
            rates: [:]
        )
        return KeeperCore.WalletBalance(
            date: Date(timeIntervalSince1970: 0),
            balance: Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [tsTON]),
            stacking: [
                AccountStackingInfo(
                    pool: JettonMasterAddress.tonstakers,
                    amount: 0,
                    pendingDeposit: 0,
                    pendingWithdraw: pendingWithdraw,
                    readyWithdraw: 0
                ),
            ],
            batteryBalance: nil,
            tronBalance: nil
        )
    }

    func makeTonstakersPool() -> StackingPoolInfo {
        StackingPoolInfo(
            address: JettonMasterAddress.tonstakers,
            name: "Tonstakers",
            totalAmount: 0,
            implementation: StackingPoolInfo.Implementation(
                type: .liquidTF,
                name: "Tonstakers",
                description: "",
                urlString: "",
                socials: []
            ),
            apy: 4,
            minStake: 0,
            cycleStart: 0,
            cycleEnd: 0,
            isVerified: true,
            currentNominators: 0,
            maxNominators: 0,
            liquidJettonMaster: JettonMasterAddress.tonstakers,
            nominatorsStake: 0,
            validatorStake: 0,
            cycleLength: nil
        )
    }

    func makeAssets(count: Int) -> [MultichainAsset] {
        (0 ..< count).map { makeAsset(assetId: "eth/mainnet/erc20/0x\($0)", symbol: "T\($0)") }
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

    func makeEarnOffer(assetId: String) -> EarnAssetOffer {
        EarnAssetOffer(
            assetId: assetId,
            network: "mainnet",
            vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
            apy: 5
        )
    }

    func apys(in viewModel: WalletBalanceMultichainAssetsListViewModel) -> [String?]? {
        guard case let .rows(rows) = viewModel.presentation else { return nil }
        return rows.compactMap { row -> AssetBalanceRowCellContent? in
            guard case let .asset(content) = row else { return nil }
            return content
        }.map(\.apy)
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

    func makeWallet(evmAddress: String? = nil) -> Wallet {
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
                MultichainWalletState(
                    walletId: "multichain-wallet",
                    addresses: evmAddress.map { [MultichainWalletAddress(chain: .eth, address: $0)] } ?? []
                )
            )
        )
    }

    func makeAmountFormatter() -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
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
    var balance: KeeperCore.WalletBalance?

    func getBalance(address _: FriendlyAddress) throws -> KeeperCore.WalletBalance {
        guard let balance else { throw StubError() }
        return balance
    }
}

private struct RatesRepositoryStub: RatesRepository {
    func saveRates(_: Rates) throws {}

    func getRates() throws -> Rates {
        throw StubError()
    }
}

private struct StakingPoolsInfoRepositoryStub: StakingPoolsInfoRepository {
    var pools: [StackingPoolInfo] = []

    func getStakingPoolsInfo(wallet _: Wallet) -> [StackingPoolInfo] {
        pools
    }

    func setStakingPoolsInfo(_: [StackingPoolInfo], wallet _: Wallet) throws {}
}

private final class WalletAssetsRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var _hideDust = [Bool?]()

    var hideDust: [Bool?] {
        lock.withLock { _hideDust }
    }

    func append(hideDust: Bool?) {
        lock.withLock { _hideDust.append(hideDust) }
    }
}

/// Holds the pages after the first one until the test opens it.
private final class RemainingPagesGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waiters = [CheckedContinuation<Void, Never>]()

    func wait() async {
        await withCheckedContinuation { continuation in
            let isOpen = lock.withLock {
                if !self.isOpen {
                    waiters.append(continuation)
                }
                return self.isOpen
            }
            if isOpen {
                continuation.resume()
            }
        }
    }

    func open() {
        let waiters = lock.withLock {
            isOpen = true
            defer { self.waiters = [] }
            return self.waiters
        }
        waiters.forEach { $0.resume() }
    }
}

private struct MultichainServiceStub: MultichainService {
    let walletAssetsPage: MultichainWalletAssetsPage?
    let dustFilteredWalletAssetsPage: MultichainWalletAssetsPage?
    let firstWalletAssetsPage: MultichainWalletAssetsPage?
    let remainingPages: RemainingPagesGate
    let walletAssetsRequests = WalletAssetsRequestLog()

    init(
        walletAssetsPage: MultichainWalletAssetsPage? = nil,
        dustFilteredWalletAssetsPage: MultichainWalletAssetsPage? = nil,
        firstWalletAssetsPage: MultichainWalletAssetsPage? = nil,
        remainingPages: RemainingPagesGate = RemainingPagesGate()
    ) {
        self.walletAssetsPage = walletAssetsPage
        self.dustFilteredWalletAssetsPage = dustFilteredWalletAssetsPage
        self.firstWalletAssetsPage = firstWalletAssetsPage
        self.remainingPages = remainingPages
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
        showAll _: Bool?,
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
        showAll _: Bool?,
        hideDust: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        walletAssetsRequests.append(hideDust: hideDust)
        if hideDust == true, let dustFilteredWalletAssetsPage {
            return dustFilteredWalletAssetsPage
        }
        if let walletAssetsPage {
            return walletAssetsPage
        }
        throw .apiError(message: "Unimplemented")
    }

    func getAllWalletAssets(
        state: MultichainWalletState,
        currencies: [String],
        capabilities: [MultichainAssetCapability]?,
        chain: MultichainChain?,
        search: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        showAll: Bool?,
        hideDust: Bool?,
        onFirstPage: (MultichainWalletAssetsPage) -> Void
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        if let firstWalletAssetsPage {
            onFirstPage(firstWalletAssetsPage)
            await remainingPages.wait()
        }
        return try await getAllWalletAssets(
            state: state,
            currencies: currencies,
            capabilities: capabilities,
            chain: chain,
            search: search,
            availableOnly: availableOnly,
            showHidden: showHidden,
            showAll: showAll,
            hideDust: hideDust
        )
    }

    func getWalletAssetIncludingUnheld(state _: MultichainWalletState, assetId _: String, currencies _: [String]) async throws(MultichainServiceError) -> MultichainAsset? {
        nil
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
        market _: Int?,
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

private struct EarnAssetOffersRepositoryStub: EarnAssetOffersRepository {
    let offers: [EarnAssetOffer]

    func offers(assetIds: [String]) async throws -> [String: EarnAssetOffer] {
        Dictionary(uniqueKeysWithValues: offers.filter { assetIds.contains($0.assetId) }.map { ($0.assetId, $0) })
    }
}

private actor EarnAssetOffersRepositorySpy: EarnAssetOffersRepository {
    private let stub: EarnAssetOffersRepositoryStub
    private var failingRequests: Int
    private(set) var requestCount = 0

    init(offers: [EarnAssetOffer], failingRequests: Int) {
        stub = EarnAssetOffersRepositoryStub(offers: offers)
        self.failingRequests = failingRequests
    }

    func offers(assetIds: [String]) async throws -> [String: EarnAssetOffer] {
        requestCount += 1
        guard failingRequests == 0 else {
            failingRequests -= 1
            throw StubError()
        }
        return try await stub.offers(assetIds: assetIds)
    }
}
