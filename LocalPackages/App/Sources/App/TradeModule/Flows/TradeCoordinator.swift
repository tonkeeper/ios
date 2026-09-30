import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import UIKit

final class TradeCoordinator: RouterCoordinator<NavigationControllerRouter> {
    /// Raw deeplink dispatch, forwarded to `MainCoordinator.handleDeeplink`.
    var didRequestDeeplinkHandling: ((String) -> Void)?
    var didRequestOpenMigration: ((@escaping () -> Void) -> Void)?

    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let tradeAssetDetailsHotWindow: TradeAssetDetailsHotWindow
    private let analyticsProvider: AnalyticsProvider
    private let amountFormatter: AmountFormatter
    private let shelvesService: TradingShelvesService
    private let favoriteAssetsService: TradingFavoriteAssetsService
    private let assetsListService: TradingAssetsListService
    private let assetDetailsService: TradingAssetDetailsService
    private let balanceService: BalanceService
    private let ratesService: RatesService
    private let jettonService: JettonService
    private let currencyStore: CurrencyStore
    private let signedAmountFormatter: AmountFormatter
    private let chartViewStateProvider: (Wallet, String) -> TokenChartViewState?
    private let output: TradeModule.CoordinatorOutput
    private weak var shelvesViewController: TradeViewController?

    init(
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        tradeAssetDetailsHotWindow: TradeAssetDetailsHotWindow,
        jettonService: JettonService,
        shelvesService: TradingShelvesService,
        favoriteAssetsService: TradingFavoriteAssetsService,
        assetsListService: TradingAssetsListService,
        assetDetailsService: TradingAssetDetailsService,
        balanceService: BalanceService,
        ratesService: RatesService,
        currencyStore: CurrencyStore,
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter,
        chartViewStateProvider: @escaping (Wallet, String) -> TokenChartViewState?,
        output: TradeModule.CoordinatorOutput
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.tradeAssetDetailsHotWindow = tradeAssetDetailsHotWindow
        self.analyticsProvider = coreAssembly.analyticsProvider
        self.amountFormatter = amountFormatter
        self.signedAmountFormatter = signedAmountFormatter
        self.shelvesService = shelvesService
        self.favoriteAssetsService = favoriteAssetsService
        self.assetsListService = assetsListService
        self.assetDetailsService = assetDetailsService
        self.jettonService = jettonService
        self.balanceService = balanceService
        self.ratesService = ratesService
        self.currencyStore = currencyStore
        self.chartViewStateProvider = chartViewStateProvider
        self.output = output
        super.init(router: router)
        router.rootViewController.tabBarItem.title = TKLocales.Tabs.trade
        router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.trade
    }

    override func start() {
        openShelves(tradeFlowAnalyticsSource: .tabBar)
    }
}

extension TradeCoordinator {
    func openRoot(animated: Bool) {
        router.rootViewController.popToRootViewController(animated: animated)
    }

    func scrollToGrid(id: String) {
        shelvesViewController?.scrollToGrid(id: id)
    }

    func openShelves(
        tradeFlowAnalyticsSource: TradeFlowAnalyticsSource
    ) {
        let perpsShelfMarketsLoader: (() async throws -> [PerpsMarketSummary])?
        if output.onOpenPerpsMarket != nil {
            let marketsRepository = keeperCoreMainAssembly.perpsAssembly.marketsRepository
            perpsShelfMarketsLoader = {
                try await marketsRepository.markets(
                    query: nil,
                    sort: .volume,
                    cursor: nil,
                    pageSize: PerpsMarketsRepository.minimumPageSize
                ).items
            }
        } else {
            perpsShelfMarketsLoader = nil
        }

        let viewModel = TradeViewModel(
            analyticsProvider: analyticsProvider,
            analyticsSource: tradeFlowAnalyticsSource,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            shelvesService: shelvesService,
            favoriteAssetsService: favoriteAssetsService,
            perpsShelfMarketsLoader: perpsShelfMarketsLoader,
            raffleStore: keeperCoreMainAssembly.storesAssembly.raffleStore,
            signedAmountFormatter: signedAmountFormatter,
            onOpenAssetList: { [weak self] category, initialCatalogSearchSort in
                guard let self else { return }
                openAssetList(
                    initialCategory: category,
                    initialCatalogSearchSort: initialCatalogSearchSort,
                    tradeFlowAnalyticsSource: tradeFlowAnalyticsSource
                )
            },
            onOpenPerps: output.onOpenPerps.map { onOpenPerps in
                { [weak self] in
                    onOpenPerps(self?.router.rootViewController)
                }
            },
            onOpenPerpsMarket: output.onOpenPerpsMarket.map { onOpenPerpsMarket in
                { [weak self] marketID in
                    onOpenPerpsMarket(marketID, self?.router.rootViewController)
                }
            },
            onOpenAssetDetails: { [weak self] preview in
                guard let self else { return }
                self.openAssetDetails(
                    preview: preview,
                    on: self.router.rootViewController,
                    source: .tradeScreen
                )
            },
            onOpenRaffle: { [weak self] in
                self?.openMysteryRaffle()
            }
        )
        let viewController = TradeViewController(viewModel: viewModel)
        shelvesViewController = viewController
        router.push(viewController: viewController, animated: false)
    }

    func openMysteryRaffle() {
        MysteryRaffleCoordinator.presentCurrent(
            from: self,
            rootViewController: router.rootViewController,
            source: .trade,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            presentedFromBanner: true,
            openDeeplink: { [weak self] in self?.didRequestDeeplinkHandling?($0) },
            openMigration: { [weak self] onFinish in
                self?.didRequestOpenMigration?(onFinish) ?? onFinish()
            }
        )
    }

    func openAssetList(
        initialCategory: TradingAssetCategory,
        initialCatalogSearchSort: MultichainAssetSearchSort = .marketCap,
        tradeFlowAnalyticsSource: TradeFlowAnalyticsSource,
        on targetNavigationController: UINavigationController? = nil
    ) {
        let navigationController = (targetNavigationController ?? router.rootViewController)
            .tabBarHostNavigationController

        if let wallet = activeWallet(),
           let multichainState = wallet.multichainWalletState
        {
            openMultichainAssetList(
                initialCategory: initialCategory,
                initialCatalogSearchSort: initialCatalogSearchSort,
                tradeFlowAnalyticsSource: tradeFlowAnalyticsSource,
                wallet: wallet,
                multichainState: multichainState,
                on: navigationController
            )
            return
        }

        let assetDetailsSource = tradeFlowAnalyticsSource.assetViewSource

        let viewController = TradeAssetsListViewController(
            viewModel: TradeAssetsListViewModel(
                analyticsProvider: analyticsProvider,
                analyticsSource: tradeFlowAnalyticsSource,
                assetsListService: assetsListService,
                amountFormatter: amountFormatter,
                signedAmountFormatter: signedAmountFormatter,
                selectedCategory: initialCategory,
                onBack: { [weak navigationController] in
                    navigationController?.popViewController(animated: true)
                },
                onOpenAssetDetails: { [weak self, weak navigationController] asset in
                    guard let self else { return }
                    self.openAssetDetails(
                        preview: self.makePreviewContext(
                            assetID: asset.id,
                            assetCategory: asset.category,
                            title: asset.subtitle,
                            imageURL: asset.imageURL,
                            symbol: asset.symbol,
                            change24hPercent: nil,
                            isUnverified: asset.isUnverified,
                            isTrusted: asset.isTrusted
                        ),
                        on: navigationController,
                        source: assetDetailsSource
                    )
                }
            )
        )
        navigationController.pushViewController(viewController, animated: true)
    }

    func openMultichainAssetList(
        initialCategory: TradingAssetCategory,
        initialCatalogSearchSort: MultichainAssetSearchSort,
        tradeFlowAnalyticsSource: TradeFlowAnalyticsSource,
        wallet: Wallet,
        multichainState: MultichainWalletState,
        on navigationController: UINavigationController
    ) {
        let perpsRepository: PerpsMarketsRepository?
        if output.onOpenPerpsMarket != nil {
            perpsRepository = keeperCoreMainAssembly.perpsAssembly.marketsRepository
        } else {
            perpsRepository = nil
        }
        let model = SendTokenV2PickerModel(
            multichainState: multichainState,
            displayMode: .includingMarketData,
            searchBehavior: .catalog,
            multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            initialCatalogSearchSort: initialCatalogSearchSort,
            catalogSearching: perpsRepository,
            perpsSearching: perpsRepository
        )
        let module = TokenPickerV2Assembly.module(
            title: assetListTitle(for: initialCategory),
            wallet: wallet,
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            ignoresSafeArea: false,
            presentation: .pushed,
            headerStyle: .push,
            onBack: { [weak navigationController] in
                navigationController?.popViewController(animated: true)
            }
        )

        let assetDetailsSource = tradeFlowAnalyticsSource.assetViewSource
        module.output.didSelectAsset = { [weak self, weak navigationController] asset in
            guard let self else { return }
            self.openAssetDetails(
                preview: TradeItemsMapper.previewContext(for: asset),
                on: navigationController,
                source: assetDetailsSource
            )
        }
        module.output.didSelectPerpMarket = { [weak self, weak navigationController] marketID in
            self?.output.onOpenPerpsMarket?(marketID, navigationController)
        }

        module.output.didFinish = { [weak navigationController] in
            navigationController?.popViewController(animated: true)
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openAssetDetails(
        preview: TradeAssetDetailsViewModel.PreviewContext,
        on navigationController: UINavigationController?,
        source: AssetViewAnalyticsSource
    ) {
        guard let wallet = activeWallet() else {
            return
        }
        let navigationController = (navigationController ?? router.rootViewController)
            .tabBarHostNavigationController
        let typedAssetId = TradingAssetToken(assetId: preview.assetID)
        let multichainAssetBalanceProvider = keeperCoreMainAssembly
            .multichainAssembly
            .multichainAssetBalanceProvider
        let convertedBalanceStore = keeperCoreMainAssembly
            .storesAssembly
            .convertedBalanceStore
        let isMultichainTransferSupported: (MultichainAsset) -> Bool = { [keeperCoreMainAssembly] asset in
            keeperCoreMainAssembly.multichainAssembly.chainKitService.isTransferSupported(asset: asset)
        }
        let multichainState = wallet.multichainWalletState
        let visibilityChangesController = multichainState.map { _ in
            keeperCoreMainAssembly.visibilityChangesController
        }
        let balanceSource = TradeAssetDetailsBalanceSource(
            typedAssetId: typedAssetId,
            wallet: wallet
        )
        // TRC20 transfers are paid for out of TRX, battery charges or GRAM, none of which the
        // asset catalog knows about; only a legacy wallet spends them through this screen.
        let tronFeesViewModel: TradeAssetDetailsTronFeesViewModel? = switch balanceSource {
        case .legacyStore(.tronUsdt):
            TradeAssetDetailsTronFeesViewModel(
                wallet: wallet,
                feesService: keeperCoreMainAssembly.servicesAssembly.tronUSDTFeesService,
                balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore
            )
        default:
            nil
        }
        let balanceViewModel: any TradeAssetDetailsBalanceViewModeling = switch balanceSource {
        case let .legacyStore(token):
            TradeAssetDetailsStoreBalanceViewModel(
                wallet: wallet,
                assetID: preview.assetID,
                typedAssetId: token,
                balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
                convertedBalanceStore: convertedBalanceStore,
                multichainAssetBalanceProvider: multichainAssetBalanceProvider
            )
        case .multichain:
            TradeAssetDetailsMultichainBalanceViewModel(
                wallet: wallet,
                assetID: preview.assetID,
                multichainAssetBalanceProvider: multichainAssetBalanceProvider,
                balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
                hotWindow: tradeAssetDetailsHotWindow,
                currencyProvider: { [currencyStore] in
                    currencyStore.state
                },
                isMultichainTransferSupported: isMultichainTransferSupported
            )
        }

        let historySource: TradeAssetDetailsViewModel.HistorySource
        if let multichainState {
            historySource = .multichain(
                TradeAssetDetailsMultichainHistoryViewModel(
                    assetId: preview.assetID,
                    multichainState: multichainState,
                    multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
                    amountFormatter: amountFormatter,
                    dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
                )
            )
        } else {
            historySource = .legacy(
                TradeAssetDetailsHistoryViewModel(
                    wallet: wallet,
                    typedAssetId: typedAssetId,
                    historyService: keeperCoreMainAssembly.servicesAssembly.historyService(),
                    tronUSDTHistoryService: keeperCoreMainAssembly.servicesAssembly.tronUSDTHistoryService(),
                    tronTRXHistoryService: keeperCoreMainAssembly.servicesAssembly.tronTRXHistoryService(),
                    tronUsdtApi: keeperCoreMainAssembly.servicesAssembly.tronUsdtApi(),
                    accountEventMapper: keeperCoreMainAssembly.mappersAssembly.historyAccountEventMapper,
                    dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
                    signedAmountFormatter: signedAmountFormatter,
                    walletNFTsManagementStoreProvider: { [keeperCoreMainAssembly] wallet in
                        keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet)
                    },
                    backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate
                )
            )
        }

        let viewController = TradeAssetDetailsViewController(
            viewModel: TradeAssetDetailsViewModel(
                multichainState: multichainState,
                preview: preview,
                isSwapDisabled: keeperCoreMainAssembly.configurationAssembly.configuration.flag(\.isSwapDisable, network: wallet.network),
                analyticsProvider: analyticsProvider,
                analyticsSource: source,
                favoriteAssetsService: favoriteAssetsService,
                tooltipsService: coreAssembly.tooltipsAssembly.service,
                assetDetailsService: assetDetailsService,
                visibilityChangesController: visibilityChangesController,
                explorerProvider: MultichainAssetExplorerProvider(
                    explorersProvider: { [keeperCoreMainAssembly] in
                        keeperCoreMainAssembly.configurationAssembly.configuration.explorers(network: wallet.network)
                    }
                ),
                appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
                currencyStore: currencyStore,
                amountFormatter: amountFormatter,
                signedAmountFormatter: signedAmountFormatter,
                tokenDetailsConfiguratorProvider: { [weak self] assetInfo in
                    guard
                        let self,
                        let wallet = activeWallet(),
                        let token = await token(for: assetInfo, wallet: wallet)
                    else {
                        return nil
                    }
                    return output.tokenDetailsConfiguratorProvider(wallet, token)
                },
                marketDataViewModel: TradeAssetDetailsMarketDataViewModel(
                    typedAssetId: typedAssetId,
                    ratesService: ratesService,
                    currencyStore: currencyStore,
                    amountFormatter: amountFormatter,
                    signedAmountFormatter: signedAmountFormatter
                ),
                balanceViewModel: balanceViewModel,
                historySource: historySource,
                tronFeesViewModel: tronFeesViewModel,
                tonStakingAPYProvider: { [keeperCoreMainAssembly] in
                    let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
                    guard !configuration.flag(\.stakingDisabled, network: wallet.network) else {
                        return nil
                    }

                    return keeperCoreMainAssembly.storesAssembly.stackingPoolsStore.state[wallet]?
                        .filter { configuration.value(\.stakingEnabledProviders).contains($0.implementation.type.rawValue) }
                        .map(\.apy)
                        .max()
                },
                onOpenUrl: { [weak self, weak navigationController] url in
                    guard let self else { return }
                    output.onOpenUrl(url, navigationController)
                },
                chartState: chartViewStateProvider(wallet, preview.assetID),
                onOpenHistory: { [weak self, weak navigationController] context in
                    guard let self else { return }
                    openAssetHistory(
                        context: context,
                        on: navigationController
                    )
                },
                onOpenHistoryEvent: { [weak self, weak navigationController] selection in
                    guard let self else { return }
                    output.onOpenHistoryEvent(selection, navigationController)
                },
                onOpenMultichainHistory: { [weak self, weak navigationController] multichainState, assetId in
                    guard let self else { return }
                    openMultichainAssetHistory(
                        multichainState: multichainState,
                        assetId: assetId,
                        on: navigationController
                    )
                },
                onBuy: { [weak self, weak navigationController] assetInfo in
                    guard let wallet = self?.activeWallet() else {
                        return
                    }
                    Task { @MainActor [weak self] in
                        guard let self else {
                            return
                        }
                        await openTradeAssetSwap(
                            wallet: wallet,
                            assetInfo: assetInfo,
                            direction: .buy,
                            navigationController: navigationController
                        )
                    }
                },
                onSell: { [weak self, weak navigationController] assetInfo in
                    guard let wallet = self?.activeWallet() else {
                        return
                    }
                    Task { @MainActor [weak self] in
                        guard let self else {
                            return
                        }
                        await openTradeAssetSwap(
                            wallet: wallet,
                            assetInfo: assetInfo,
                            direction: .sell,
                            navigationController: navigationController
                        )
                    }
                },
                onSend: { [weak self, weak navigationController] assetInfo, resolvedAsset in
                    guard let self, let wallet = activeWallet() else {
                        return
                    }
                    if wallet.isMultichain,
                       case let .multichain(multichainState) = wallet.multichain,
                       let resolvedAsset,
                       let sendInput = multichainSendInput(asset: resolvedAsset)
                    {
                        output.onSendMultichain(wallet, multichainState, sendInput, navigationController)
                        return
                    }
                    Task { @MainActor [weak self] in
                        guard let self else {
                            return
                        }
                        if wallet.isMultichain, case let .multichain(multichainState) = wallet.multichain {
                            guard let sendInput = await multichainSendInput(
                                multichainState: multichainState,
                                assetId: assetInfo.assetId
                            ) else {
                                ToastPresenter.showToast(
                                    configuration: ToastPresenter.Configuration(
                                        title: TKLocales.Trade.Assets.Errors.load
                                    )
                                )
                                return
                            }
                            output.onSendMultichain(wallet, multichainState, sendInput, navigationController)
                        } else if let token = await token(for: assetInfo, wallet: wallet) {
                            output.onSend(wallet, token.sendV3Item, navigationController)
                        }
                    }
                },
                onReceive: { [weak self, weak navigationController] assetInfo in
                    guard let wallet = self?.activeWallet() else {
                        return
                    }
                    Task { @MainActor [weak self] in
                        guard let self else {
                            return
                        }
                        if wallet.isMultichain, case let .multichain(multichainState) = wallet.multichain {
                            guard let address = multichainReceiveAddress(
                                for: assetInfo,
                                multichainState: multichainState,
                                wallet: wallet
                            ) else {
                                ToastPresenter.showToast(
                                    configuration: ToastPresenter.Configuration(
                                        title: TKLocales.Trade.Assets.Errors.load
                                    )
                                )
                                return
                            }
                            output.onReceiveMultichain(wallet, address, navigationController)
                        } else if let token = await token(for: assetInfo, wallet: wallet) {
                            output.onReceive(token, wallet, navigationController)
                        }
                    }
                },
                onSellToCard: { [weak self, weak navigationController] assetInfo, resolvedAsset in
                    self?.openSellToCard(
                        assetInfo: assetInfo,
                        resolvedAsset: resolvedAsset,
                        navigationController: navigationController
                    )
                },
                onCashBuy: { [weak self, weak navigationController] assetInfo in
                    self?.openCashBuy(
                        assetInfo: assetInfo,
                        navigationController: navigationController
                    )
                },
                onTronFees: { [output, wallet] snapshot, trigger in
                    output.onTronUsdtFees(wallet, snapshot, trigger)
                },
                onOpenStaking: { [output] in
                    output.onOpenStaking(wallet)
                },
                onOpenTokenizedInfo: { [weak self] kind in
                    guard let self else { return }
                    openTokenizedAssetInfoPopup(kind: kind)
                },
                onOpenUnverifiedTokenInfo: { [output, weak navigationController] in
                    output.onOpenUnverifiedTokenInfoPopup(navigationController)
                },
                onOpenVerifiedTokenInfo: { [output, weak navigationController] in
                    output.onOpenVerifiedTokenInfoPopup(navigationController)
                },
                onAssetVisibilityChanged: { [keeperCoreMainAssembly, wallet] in
                    let balanceLoader = keeperCoreMainAssembly.loadersAssembly.balanceLoader
                    Task {
                        await balanceLoader.reloadBalance(wallet: wallet, priority: .userInitiated)
                    }
                },
                onBack: { [weak navigationController] in
                    navigationController?.popViewController(animated: true)
                }
            )
        )

        navigationController.pushViewController(viewController, animated: true)
    }

    func openAssetDetails(
        assetID: String,
        source: AssetViewAnalyticsSource
    ) {
        openAssetDetails(
            preview: makePreviewContext(assetID: assetID),
            on: router.rootViewController,
            source: source
        )
    }

    func openAssetHistory(
        context: TradeAssetHistoryContext,
        on navigationController: UINavigationController?
    ) {
        let presentingNavigationController = (navigationController ?? router.rootViewController)
            .tabBarHostNavigationController
        let module = historyListModule(for: context)

        module.output.didSelectEvent = { [weak self, weak presentingNavigationController] event in
            guard let self else {
                return
            }
            switch event {
            case let .tonEvent(event):
                output.onOpenHistoryEvent(
                    .ton(wallet: wallet(for: context), event: event),
                    presentingNavigationController
                )
            case let .tronEvent(event):
                output.onOpenHistoryEvent(
                    .tron(wallet: wallet(for: context), event: event),
                    presentingNavigationController
                )
            }
        }

        let viewController = TradeAssetHistoryViewController(
            listViewController: module.view,
            onBack: { [weak presentingNavigationController] in
                presentingNavigationController?.popViewController(animated: true)
            }
        )
        viewController.navigationItem.hidesBackButton = true
        presentingNavigationController.pushViewController(viewController, animated: true)
    }

    func openMultichainAssetHistory(
        multichainState: MultichainWalletState,
        assetId: String,
        on navigationController: UINavigationController?
    ) {
        let presentingNavigationController = (navigationController ?? router.rootViewController)
            .tabBarHostNavigationController
        let appSettingsStore = keeperCoreMainAssembly.storesAssembly.appSettingsStore
        let viewModel = MultichainHistoryViewModelImplementation(
            multichainState: multichainState,
            assetId: assetId,
            hidesDustTransactions: appSettingsStore.getState().hidesDustTransactions,
            multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
            realtimeManager: keeperCoreMainAssembly.multichainAssembly.realtimeManager,
            reachabilityTracker: coreAssembly.reachabilityTracker,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
            nftResolver: MultichainActivityNFTResolver(
                nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
                network: activeWallet()?.network ?? .mainnet
            )
        )
        viewModel.persistHistoryFilters(to: appSettingsStore)
        let viewController = MultichainHistoryViewController(
            viewModel: viewModel,
            onClose: { [weak presentingNavigationController] in
                presentingNavigationController?.popViewController(animated: true)
            },
            onOpenTransaction: { [output, weak presentingNavigationController] url, _ in
                output.onOpenUrl(url, presentingNavigationController)
            }
        )
        viewController.navigationItem.hidesBackButton = true
        presentingNavigationController.pushViewController(viewController, animated: true)
    }
}

private extension TradeCoordinator {
    func makePreviewContext(
        assetID: String,
        assetCategory: TradingAssetCategory?,
        title: String,
        imageURL: URL?,
        symbol: String,
        change24hPercent: Decimal?,
        isUnverified: Bool?,
        isTrusted: Bool?
    ) -> TradeAssetDetailsViewModel.PreviewContext {
        TradeAssetDetailsViewModel.PreviewContext(
            assetID: assetID,
            assetCategory: assetCategory,
            title: title,
            imageURL: imageURL,
            symbol: symbol,
            change24hPercent: change24hPercent,
            isUnverified: isUnverified,
            isTrusted: isTrusted
        )
    }

    func makePreviewContext(assetID: String) -> TradeAssetDetailsViewModel.PreviewContext {
        TradeAssetDetailsViewModel.PreviewContext(
            assetID: assetID
        )
    }

    func assetListTitle(for category: TradingAssetCategory) -> String {
        switch category {
        case .all, .tokens:
            TKLocales.Trade.Assets.title
        case .stocks:
            TKLocales.Trade.Assets.Categories.stocks
        case .etfs:
            TKLocales.Trade.Assets.Categories.etfs
        }
    }
}

private extension TradeCoordinator {
    func openSellToCard(
        assetInfo: TradingAssetInfo,
        resolvedAsset: MultichainAsset?,
        navigationController: UINavigationController?
    ) {
        guard
            let wallet = activeWallet(),
            wallet.isMultichain
        else {
            return
        }
        output.onSellToCard(wallet, assetInfo, resolvedAsset, navigationController)
    }

    func openCashBuy(
        assetInfo: TradingAssetInfo,
        navigationController: UINavigationController?
    ) {
        guard
            let wallet = activeWallet(),
            wallet.isMultichain
        else {
            return
        }
        output.onCashBuy(wallet, assetInfo, navigationController)
    }

    func activeWallet() -> Wallet? {
        try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet
    }

    func multichainSendInput(
        multichainState: MultichainWalletState,
        assetId: String
    ) async -> MultichainSendInput? {
        let assetResolver = MultichainSendAssetResolver(
            multichainAssetBalanceProvider: keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider,
            assetDetailsService: keeperCoreMainAssembly.servicesAssembly.assetDetailsService()
        )
        guard let asset = await assetResolver.resolveAsset(for: assetId, multichainState: multichainState) else {
            return nil
        }
        return multichainSendInput(asset: asset)
    }

    func multichainSendInput(asset: MultichainAsset) -> MultichainSendInput? {
        guard keeperCoreMainAssembly.multichainAssembly.chainKitService.isTransferSupported(asset: asset) else {
            return nil
        }
        return MultichainSendInput(item: MultichainSendItem(asset: asset, amount: 0))
    }

    func multichainReceiveAddress(
        for assetInfo: TradingAssetInfo,
        multichainState: MultichainWalletState,
        wallet: Wallet
    ) -> ReceiveAddressPreview? {
        guard
            let components = AssetIdComponents(assetId: assetInfo.assetId),
            let chain = MultichainChain(assetIdChain: components.chain),
            let walletAddress = multichainState.walletAddress(
                for: chain,
                preferredType: wallet.preferredMultichainAddressType(for: chain)
            )
        else {
            return nil
        }

        switch components {
        case .coin:
            return ReceiveAddressPreview(address: walletAddress)
        case let .asset(_, _, _, contractAddress):
            let qrPayload: String
            if chain == .ton,
               let jettonAddress = try? AnyAddress(rawAddress: contractAddress).address,
               let deeplink = try? DeeplinkGenerator().generateTransferDeeplink(
                   with: walletAddress.address,
                   jettonAddress: jettonAddress
               )
            {
                qrPayload = deeplink
            } else {
                qrPayload = walletAddress.address
            }

            return ReceiveAddressPreview(
                address: walletAddress,
                qrPayload: qrPayload,
                asset: ReceiveAddressPreview.Asset(
                    address: contractAddress,
                    name: assetInfo.title,
                    symbol: assetInfo.symbol,
                    icon: .url(assetInfo.imageURL)
                )
            )
        }
    }

    func token(for assetInfo: TradingAssetInfo, wallet: Wallet) async -> Token? {
        await token(for: assetInfo.typedAssetId, wallet: wallet)
    }

    func token(for tradeAssetBalanceIdentifier: TradingAssetToken?, wallet: Wallet) async -> Token? {
        switch tradeAssetBalanceIdentifier {
        case .ton:
            return .ton(.ton)
        case .tronUsdt:
            return .tron(.usdt)
        case .tronTrx:
            return .tron(.trx)
        case let .jetton(address):
            if let walletBalance = try? balanceService.getBalance(wallet: wallet),
               let jettonItem = walletBalance.balance.jettonsBalance.first(where: {
                   $0.item.jettonInfo.address == address
               })?.item
            {
                return .ton(.jetton(jettonItem))
            }

            return await Task { @MainActor in
                ToastPresenter.showToast(configuration: .loading)
                let token: Token
                do {
                    token = try await .ton(
                        .jetton(
                            JettonItem(
                                jettonInfo: jettonService.jettonInfo(
                                    address: address,
                                    network: wallet.network
                                ),
                                walletAddress: nil
                            )
                        )
                    )
                    ToastPresenter.hideToast()
                } catch {
                    Log.w("failed to resolve jetton info due to error: \(error.localizedDescription)")
                    ToastPresenter.hideToast()
                    ToastPresenter.showToast(
                        configuration: ToastPresenter.Configuration(
                            title: TKLocales.Trade.Assets.Errors.load
                        )
                    )
                    return nil
                }
                return token
            }.value
        case nil:
            await MainActor.run {
                ToastPresenter.showToast(
                    configuration: ToastPresenter.Configuration(
                        title: TKLocales.Trade.Assets.Errors.load
                    )
                )
            }
            return nil
        }
    }

    func historyListModule(
        for context: TradeAssetHistoryContext
    ) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput> {
        let historyModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        switch context {
        case let .ton(wallet):
            return historyModule.createTonHistoryListModule(wallet: wallet)
        case let .jetton(wallet, jettonMasterAddress):
            return historyModule.createJettonHistoryListModule(
                jettonMasterAddress: jettonMasterAddress,
                wallet: wallet
            )
        case let .tronUSDT(wallet):
            return historyModule.createTronUSDTHistoryListModule(wallet: wallet)
        case let .tronTRX(wallet):
            return historyModule.createTronTRXHistoryListModule(wallet: wallet)
        }
    }

    func wallet(for context: TradeAssetHistoryContext) -> Wallet {
        switch context {
        case let .ton(wallet), let .tronUSDT(wallet), let .tronTRX(wallet), let .jetton(wallet, _):
            return wallet
        }
    }

    func openTokenizedAssetInfoPopup(kind: TokenizedAssetInfoKind) {
        PopupContentPresenter.presentTokenized(
            kind: kind,
            from: router.rootViewController.topPresentedViewController()
        )
    }

    private enum TradeAssetSwapDirection {
        case buy
        case sell

        var multichainSwapInitialSelectionSide: MultichainSwapInitialAssetSelection.Side {
            switch self {
            case .buy:
                return .receive
            case .sell:
                return .send
            }
        }
    }

    private func openTradeAssetSwap(
        wallet: Wallet,
        assetInfo: TradingAssetInfo,
        direction: TradeAssetSwapDirection,
        navigationController: UINavigationController?
    ) async {
        if wallet.isMultichain, case .multichain = wallet.multichain {
            output.onSwap(
                .multichain(
                    MultichainSwapInitialAssetSelection(
                        assetId: assetInfo.assetId,
                        side: direction.multichainSwapInitialSelectionSide
                    )
                ),
                wallet,
                navigationController
            )
            return
        }

        guard let token = await token(for: assetInfo, wallet: wallet) else {
            return
        }

        await openTradeAssetSwap(
            wallet: wallet,
            token: token,
            tokenCategory: assetInfo.category,
            direction: direction,
            navigationController: navigationController
        )
    }

    private func openTradeAssetSwap(
        wallet: Wallet,
        token: Token,
        tokenCategory: TradingAssetCategory,
        direction: TradeAssetSwapDirection,
        navigationController: UINavigationController?
    ) async {
        switch token {
        case let .ton(tonToken):
            let fromToken: TonToken
            let toToken: TonToken
            let fromCategory: TradingAssetCategory
            let toCategory: TradingAssetCategory
            switch tonToken {
            case .ton:
                guard
                    let usdtAnyToken = await self.token(for: .jetton(JettonMasterAddress.tonUSDT), wallet: wallet)
                else {
                    return
                }
                guard case let .ton(usdt) = usdtAnyToken else {
                    return output.onSwap(
                        .tron,
                        wallet,
                        navigationController
                    )
                }
                switch direction {
                case .buy:
                    fromToken = usdt
                    toToken = .ton
                    fromCategory = .tokens
                    toCategory = .tokens
                case .sell:
                    fromToken = .ton
                    toToken = usdt
                    fromCategory = .tokens
                    toCategory = .tokens
                }
            case let .jetton(item):
                let counterpartToken: TonToken
                if item.jettonInfo.address == JettonMasterAddress.SPYx {
                    counterpartToken = .ton
                } else if tokenCategory.requiresUSDTNativeSwapCounterpart {
                    guard
                        let usdtAnyToken = await self.token(for: .jetton(JettonMasterAddress.tonUSDT), wallet: wallet),
                        case let .ton(usdt) = usdtAnyToken
                    else {
                        return
                    }
                    counterpartToken = usdt
                } else {
                    counterpartToken = .ton
                }
                switch direction {
                case .buy:
                    fromToken = counterpartToken
                    toToken = .jetton(item)
                    fromCategory = .tokens
                    toCategory = tokenCategory
                case .sell:
                    fromToken = .jetton(item)
                    toToken = counterpartToken
                    fromCategory = tokenCategory
                    toCategory = .tokens
                }
            }
            output.onSwap(
                .ton(
                    from: fromToken,
                    to: toToken,
                    fromCategory: fromCategory,
                    toCategory: toCategory
                ),
                wallet,
                navigationController
            )
        case .tron:
            output.onSwap(
                .tron,
                wallet,
                navigationController
            )
        }
    }
}

private extension TradingAssetCategory {
    var requiresUSDTNativeSwapCounterpart: Bool {
        switch self {
        case .stocks, .etfs:
            return true
        case .all, .tokens:
            return false
        }
    }
}
