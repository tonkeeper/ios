import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit
import UIKit

public final class MultichainWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didTapScan: (() -> Void)?
    /// Raw deeplink dispatch, forwarded to `MainCoordinator.handleDeeplink`.
    var didRequestDeeplinkHandling: ((String) -> Void)?
    var didRequestOpenMigration: ((@escaping () -> Void) -> Void)?
    var didTapWalletButton: (() -> Void)?
    var didTapSend: ((Wallet) -> Void)?
    var didTapWithdraw: ((Wallet) -> Void)?
    var didTapDeposit: ((Wallet) -> Void)?
    var didTapSwap: ((Wallet) -> Void)?
    var didTapStake: ((Wallet) -> Void)?
    var didTapSettingsButton: ((Wallet) -> Void)?
    var didTapHistoryButton: (() -> Void)?
    var didSelectTonDetails: ((Wallet) -> Void)?
    var didSelectJettonDetails: ((Wallet, JettonItem, Bool) -> Void)?
    var didSelectTronUSDTDetails: ((Wallet) -> Void)?
    var didSelectTronTRXDetails: ((Wallet) -> Void)?
    var didSelectEthenaDetails: ((Wallet) -> Void)?
    var didSelectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?
    var didSelectCollectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?
    var didTapBackup: ((Wallet) -> Void)?
    var didTapMigration: ((Wallet) -> Void)?
    var didTapBattery: ((Wallet) -> Void)?
    var didTapAddress: ((Wallet) -> Void)?
    var didSelectMultichainAssetDetails: ((TradeAssetDetailsViewModel.PreviewContext) -> Void)?
    var didTapOpenCryptoAssets: (() -> Void)?
    var collectiblesDidOpenDapp: ((_ url: URL, _ title: String?) -> Void)?
    var collectiblesDidRequestDeeplinkHandling: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    var didRequestBannerDeeplinkHandling: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    var collectiblesDidRequestOpenBuySell: ((_ isInternalPurchasing: Bool, _ wallet: Wallet) -> Void)?
    var collectiblesDidRequestDepositTon: ((_ wallet: Wallet) -> Void)?

    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let collectiblesModule: CollectiblesModule

    private weak var walletContainerViewController: WalletContainerViewController?
    private weak var collectiblesCoordinator: CollectiblesCoordinator?
    private weak var collectiblesDetailsCoordinator: CollectiblesDetailsCoordinator?

    public init(
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.collectiblesModule = CollectiblesModule(
            dependencies: CollectiblesModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        super.init(router: router)
        router.rootViewController.tabBarItem.title = TKLocales.Tabs.wallet
        router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.wallet
    }

    override public func start() {
        openMultichainWalletRoot()
    }

    public func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        let deeplink = Deeplink.publish(sign: sign)
        if let collectiblesDetailsCoordinator,
           collectiblesDetailsCoordinator.handleTonkeeperDeeplink(deeplink: deeplink)
        {
            return true
        }
        if let collectiblesCoordinator,
           collectiblesCoordinator.handleTonkeeperDeeplink(deeplink: deeplink)
        {
            return true
        }
        return false
    }
}

extension MultichainWalletCoordinator: WalletTabCoordinatorOutput {
    func historyButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void) {
        walletContainerViewController?.historyButtonTooltipSourceView(completion)
    }

    func walletButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void) {
        walletContainerViewController?.walletButtonTooltipSourceView(completion)
    }
}

private extension MultichainWalletCoordinator {
    var configuration: Configuration {
        keeperCoreMainAssembly.configurationAssembly.configuration
    }

    func openMultichainWalletRoot() {
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
            return
        }

        let pushAuthorizationModel = PushAuthorizationModel()
        let totalBalanceUpdateQueue = DispatchQueue(label: "MultichainWalletTotalBalanceQueue")
        let headerMapper = WalletBalanceHeaderMapper(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
        )
        let multichainService = keeperCoreMainAssembly.servicesAssembly.multichainService()

        let rootViewModel = MultichainWalletRootViewModel(
            wallet: wallet,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            configuration: configuration,
            raffleStore: keeperCoreMainAssembly.storesAssembly.raffleStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            makeWalletViewModel: { [weak self, keeperCoreMainAssembly, coreAssembly, configuration] wallet in
                Self.makeWalletViewModel(
                    wallet: wallet,
                    coordinator: self,
                    keeperCoreMainAssembly: keeperCoreMainAssembly,
                    coreAssembly: coreAssembly,
                    configuration: configuration,
                    multichainService: multichainService,
                    headerMapper: headerMapper,
                    totalBalanceUpdateQueue: totalBalanceUpdateQueue,
                    pushAuthorizationModel: pushAuthorizationModel
                )
            }
        )
        rootViewModel.onOpenRaffle = { [weak self] in
            self?.openMysteryRaffle()
        }
        let balanceViewController = MultichainWalletBalanceViewController(viewModel: rootViewModel)
        rootViewModel.didChangeWallet = { [weak balanceViewController] in
            balanceViewController?.scrollToTop()
        }

        let module = WalletContainerAssembly.module(
            walletBalanceViewController: balanceViewController,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore
        )
        walletContainerViewController = module.view

        module.output.walletButtonHandler = { [weak self] in
            self?.didTapWalletButton?()
        }

        module.output.didTapScan = { [weak self] in
            self?.didTapScan?()
        }

        module.output.didTapSettingsButton = { [weak self] wallet in
            self?.didTapSettingsButton?(wallet)
        }

        module.output.didTapHistoryButton = { [weak self] in
            self?.didTapHistoryButton?()
        }

        router.push(viewController: module.view, animated: false)
    }

    static func makeWalletViewModel(
        wallet: Wallet,
        coordinator: MultichainWalletCoordinator?,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        configuration: Configuration,
        multichainService: MultichainService,
        headerMapper: WalletBalanceHeaderMapper,
        totalBalanceUpdateQueue: DispatchQueue,
        pushAuthorizationModel: PushAuthorizationModel
    ) -> MultichainWalletViewModel {
        let storesAssembly = keeperCoreMainAssembly.storesAssembly

        let balanceViewModel = MultichainWalletBalanceSectionViewModel(
            wallet: wallet,
            totalBalanceModel: WalletTotalBalanceModel(
                wallet: wallet,
                totalBalanceStore: storesAssembly.totalBalanceStore,
                appSettingsStore: storesAssembly.appSettingsStore,
                backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate,
                balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
                updateQueue: totalBalanceUpdateQueue
            ),
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            walletsStore: storesAssembly.walletsStore,
            portfolioStore: storesAssembly.multichainPortfolioStore,
            currencyStore: storesAssembly.currencyStore,
            appSettingsStore: storesAssembly.appSettingsStore,
            headerMapper: headerMapper,
            configuration: configuration
        )
        balanceViewModel.onAddress = { [weak coordinator] wallet in
            coordinator?.didTapAddress?(wallet)
        }
        balanceViewModel.onBattery = { [weak coordinator] wallet in
            coordinator?.didTapBattery?(wallet)
        }
        balanceViewModel.onBackup = { [weak coordinator] wallet in
            coordinator?.didTapBackup?(wallet)
        }

        let homeBannersViewModel = WalletBalanceHomeBannersViewModel(
            wallet: wallet,
            walletsStore: storesAssembly.walletsStore,
            homeBannersStore: storesAssembly.homeBannersStore,
            homeBannersLoader: keeperCoreMainAssembly.loadersAssembly.homeBannersLoader,
            deeplinkParser: keeperCoreMainAssembly.deeplinkParser,
            analyticsProvider: coreAssembly.analyticsProvider
        )
        homeBannersViewModel.onOpenDeeplink = { [weak coordinator] deeplink, utm in
            coordinator?.didRequestBannerDeeplinkHandling?(deeplink, utm)
        }
        homeBannersViewModel.onOpenLink = { url in
            coreAssembly.urlOpener().open(url: url)
        }

        let amountFormatter = keeperCoreMainAssembly.formattersAssembly.amountFormatter
        let assetsListViewModel = WalletBalanceMultichainAssetsListViewModel(
            wallet: wallet,
            multichainService: multichainService,
            multichainAssetBalanceProvider: keeperCoreMainAssembly
                .multichainAssembly
                .multichainAssetBalanceProvider,
            currencyStore: storesAssembly.currencyStore,
            amountFormatter: amountFormatter,
            portfolioStore: storesAssembly.multichainPortfolioStore,
            stakingPoolsStore: storesAssembly.stackingPoolsStore,
            processedBalanceStore: storesAssembly.processedBalanceStore,
            appSettingsStore: storesAssembly.appSettingsStore,
            tonStakingAPYProvider: { [configuration, storesAssembly] wallet in
                guard !configuration.flag(\.stakingDisabled, network: wallet.network) else {
                    return nil
                }
                return storesAssembly.stackingPoolsStore.state[wallet]?
                    .filter { configuration.value(\.stakingEnabledProviders).contains($0.implementation.type.rawValue) }
                    .map(\.apy)
                    .max()
            },
            tonStakingAPYTextFormatter: { [amountFormatter] value in
                guard let value else { return nil }
                return TKLocales.Trade.AssetDetails.apyValue(
                    amountFormatter.format(decimal: value, style: .percent)
                )
            },
            canManage: true
        )
        assetsListViewModel.onTapOpenAssets = { [weak coordinator] in
            coordinator?.didTapOpenCryptoAssets?()
        }
        assetsListViewModel.onSelectAsset = { [weak coordinator] asset in
            coordinator?.didSelectMultichainAssetDetails?(
                TradeItemsMapper.previewContext(for: asset)
            )
        }
        assetsListViewModel.onSelectStakingItem = { [weak coordinator] wallet, stakingPoolInfo, accountStakingInfo in
            coordinator?.didSelectStakingItem?(wallet, stakingPoolInfo, accountStakingInfo)
        }
        assetsListViewModel.onSelectCollectStakingItem = { [weak coordinator] wallet, stakingPoolInfo, accountStakingInfo in
            coordinator?.didSelectCollectStakingItem?(wallet, stakingPoolInfo, accountStakingInfo)
        }

        let collectiblesViewModel = WalletBalanceMultichainCollectiblesViewModel(
            wallet: wallet,
            storesAssembly: storesAssembly,
            accountNftService: keeperCoreMainAssembly.servicesAssembly.accountNftService(),
            appSettingsStore: storesAssembly.appSettingsStore
        )
        collectiblesViewModel.onTapOpenCollectibles = { [weak coordinator] in
            coordinator?.openCollectibles()
        }

        let viewModel = MultichainWalletViewModel(
            wallet: wallet,
            balanceViewModel: balanceViewModel,
            homeBannersViewModel: homeBannersViewModel,
            assetsListViewModel: assetsListViewModel,
            collectiblesViewModel: collectiblesViewModel,
            setupModel: WalletBalanceSetupModel(
                wallet: wallet,
                walletsStore: storesAssembly.walletsStore,
                processedBalanceStore: storesAssembly.processedBalanceStore,
                securityStore: storesAssembly.securityStore,
                walletNotificationStore: storesAssembly.walletNotificationStore,
                mnemonicsAccess: keeperCoreMainAssembly.secureAssembly.mnemonicAccess,
                configuration: configuration,
                pushAuthorizationModel: pushAuthorizationModel
            ),
            walletsStore: storesAssembly.walletsStore,
            multichainService: multichainService,
            realtimeManager: keeperCoreMainAssembly.multichainAssembly.realtimeManager,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            stakingPoolsStore: storesAssembly.stackingPoolsStore,
            processedBalanceStore: storesAssembly.processedBalanceStore,
            configuration: configuration,
            tooltipsService: coreAssembly.tooltipsAssembly.service
        )
        viewModel.onSend = { [weak coordinator] wallet in
            coordinator?.didTapSend?(wallet)
        }
        viewModel.onDeposit = { [weak coordinator] wallet in
            coordinator?.didTapDeposit?(wallet)
        }
        viewModel.onSwap = { [weak coordinator] wallet in
            coordinator?.didTapSwap?(wallet)
        }
        viewModel.onStake = { [weak coordinator] wallet in
            coordinator?.didTapStake?(wallet)
        }
        viewModel.onBackup = { [weak coordinator] wallet in
            coordinator?.didTapBackup?(wallet)
        }
        viewModel.onRequirePasscode = { [weak coordinator] in
            await coordinator?.getPasscode()
        }
        viewModel.onMigration = { [weak coordinator] wallet in
            coordinator?.didTapMigration?(wallet)
        }
        assetsListViewModel.onTapManage = { [weak coordinator, weak viewModel] in
            guard let coordinator, let viewModel else { return }
            coordinator.openManageTokens(walletViewModel: viewModel)
        }
        collectiblesViewModel.onSelectNFT = { [weak coordinator, weak viewModel] nft in
            guard let coordinator, let viewModel else { return }
            coordinator.openNFTDetails(wallet: viewModel.wallet, nft: nft)
        }
        return viewModel
    }

    func openMysteryRaffle() {
        MysteryRaffleCoordinator.presentCurrent(
            from: self,
            rootViewController: router.rootViewController,
            source: .walletMain,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            openDeeplink: { [weak self] in self?.didRequestDeeplinkHandling?($0) },
            openMigration: { [weak self] onFinish in
                self?.didRequestOpenMigration?(onFinish) ?? onFinish()
            }
        )
    }

    func getPasscode() async -> String? {
        await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess,
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            analyticsProvider: coreAssembly.analyticsProvider
        )
    }

    func openCollectibles() {
        guard collectiblesCoordinator == nil else { return }
        let navigationController = router.rootViewController.tabBarHostNavigationController
        let collectiblesCoordinator = collectiblesModule.createCollectiblesCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            configuresTabBarItem: false
        )
        collectiblesCoordinator.didOpenDapp = { [weak self] url, title in
            self?.collectiblesDidOpenDapp?(url, title)
        }
        collectiblesCoordinator.didRequestDeeplinkHandling = { [weak self] deeplink, utm in
            self?.collectiblesDidRequestDeeplinkHandling?(deeplink, utm)
        }
        collectiblesCoordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing, wallet in
            self?.collectiblesDidRequestOpenBuySell?(isInternalPurchasing, wallet)
        }
        collectiblesCoordinator.didRequestDepositTon = { [weak self] wallet in
            self?.collectiblesDidRequestDepositTon?(wallet)
        }

        self.collectiblesCoordinator = collectiblesCoordinator

        let removeCollectibles = { [weak self, weak collectiblesCoordinator] in
            guard let self, let collectiblesCoordinator else { return }
            self.removeChild(collectiblesCoordinator)
            if self.collectiblesCoordinator === collectiblesCoordinator {
                self.collectiblesCoordinator = nil
            }
        }

        collectiblesCoordinator.didFinish = { _ in
            removeCollectibles()
        }

        addChild(collectiblesCoordinator)
        collectiblesCoordinator.push(
            onBack: { [weak navigationController] in
                navigationController?.popViewController(animated: true)
            },
            onPop: removeCollectibles
        )
    }

    func openNFTDetails(wallet: Wallet, nft: NFT) {
        guard let wallet = keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: wallet.id) else {
            return
        }

        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = CollectiblesDetailsCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            nft: nft,
            wallet: wallet,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didOpenDapp = { [weak self] url, title in
            self?.collectiblesDidOpenDapp?(url, title)
        }

        coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
            navigationController?.dismiss(animated: true)
            guard let coordinator else { return }
            self?.removeChild(coordinator)
            self?.collectiblesDetailsCoordinator = nil
        }

        coordinator.didRequestDeeplinkHandling = { [weak self] deeplink, utm in
            self?.collectiblesDidRequestDeeplinkHandling?(deeplink, utm)
        }

        coordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            self?.collectiblesDidRequestOpenBuySell?(isInternalPurchasing, wallet)
        }

        coordinator.didRequestDepositTon = { [weak self] in
            self?.collectiblesDidRequestDepositTon?(wallet)
        }

        collectiblesDetailsCoordinator = coordinator
        coordinator.start()
        addChild(coordinator)

        router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
            self?.collectiblesDetailsCoordinator = nil
        })
    }

    func openManageTokens(walletViewModel: MultichainWalletViewModel) {
        let wallet = walletViewModel.wallet
        let coordinator = ManageTokensCoordinator(
            router: router,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            visibilityChangesController: keeperCoreMainAssembly.visibilityChangesController
        )
        coordinator.didSaveVisibilityChanges = { [weak walletViewModel] update in
            Task {
                await walletViewModel?.applyVisibilityUpdate(update)
            }
        }
        addChild(coordinator)
        coordinator.didFinish = { [weak self, weak coordinator] _ in
            self?.removeChild(coordinator)
        }

        coordinator.start()
    }
}
