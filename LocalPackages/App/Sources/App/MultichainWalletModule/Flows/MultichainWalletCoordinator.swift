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
    var collectiblesDidRequestDeeplinkHandling: ((_ deeplink: Deeplink) -> Void)?
    var didRequestBannerDeeplinkHandling: ((_ deeplink: Deeplink) -> Void)?
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
        let totalBalanceUpdateQueue = DispatchQueue(label: "MultichainWalletTotalBalanceQueue")
        let multichainService = keeperCoreMainAssembly.servicesAssembly.multichainService()

        let headerMapper = WalletBalanceHeaderMapper(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
        )

        let setupModel = WalletBalanceSetupModel(
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
            mnemonicsAccess: keeperCoreMainAssembly.secureAssembly.mnemonicAccess,
            configuration: configuration
        )

        let rootViewModel = MultichainWalletRootViewModel(
            wallet: wallet,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            setupModel: setupModel,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            multichainService: multichainService,
            multichainAssetBalanceProvider: keeperCoreMainAssembly
                .multichainAssembly
                .multichainAssetBalanceProvider,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            configuration: configuration,
            tooltipsService: coreAssembly.tooltipsAssembly.service,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            makeBalanceViewModel: { [weak self, keeperCoreMainAssembly, configuration] wallet in
                let viewModel = MultichainWalletBalanceSectionViewModel(
                    wallet: wallet,
                    totalBalanceModel: WalletTotalBalanceModel(
                        wallet: wallet,
                        totalBalanceStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
                        appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
                        backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate,
                        balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
                        updateQueue: totalBalanceUpdateQueue
                    ),
                    balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
                    walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
                    portfolioStore: keeperCoreMainAssembly.storesAssembly.multichainPortfolioStore,
                    currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
                    appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
                    headerMapper: headerMapper,
                    configuration: configuration
                )
                viewModel.onAddress = { [weak self] wallet in
                    self?.didTapAddress?(wallet)
                }
                viewModel.onBattery = { [weak self] wallet in
                    self?.didTapBattery?(wallet)
                }
                viewModel.onBackup = { [weak self] wallet in
                    self?.didTapBackup?(wallet)
                }
                return viewModel
            },
            storesAssembly: keeperCoreMainAssembly.storesAssembly,
            accountNftService: keeperCoreMainAssembly.servicesAssembly.accountNftService(),
            makeHomeBannersViewModel: { [weak self, keeperCoreMainAssembly, coreAssembly] wallet in
                let viewModel = WalletBalanceHomeBannersViewModel(
                    wallet: wallet,
                    homeBannersStore: keeperCoreMainAssembly.storesAssembly.homeBannersStore,
                    homeBannersLoader: keeperCoreMainAssembly.loadersAssembly.homeBannersLoader,
                    deeplinkParser: keeperCoreMainAssembly.deeplinkParser,
                    analyticsProvider: coreAssembly.analyticsProvider
                )
                viewModel.onOpenDeeplink = { [weak self] deeplink in
                    self?.didRequestBannerDeeplinkHandling?(deeplink)
                }
                viewModel.onOpenLink = { [weak self] url in
                    self?.coreAssembly.urlOpener().open(url: url)
                }
                return viewModel
            },
            raffleStore: keeperCoreMainAssembly.storesAssembly.raffleStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            realtimeManager: keeperCoreMainAssembly.multichainAssembly.realtimeManager
        )
        rootViewModel.onSend = { [weak self] wallet in
            self?.didTapSend?(wallet)
        }
        rootViewModel.onDeposit = { [weak self] wallet in
            self?.didTapDeposit?(wallet)
        }
        rootViewModel.onSwap = { [weak self] wallet in
            self?.didTapSwap?(wallet)
        }
        rootViewModel.onStake = { [weak self] wallet in
            self?.didTapStake?(wallet)
        }
        rootViewModel.onBackup = { [weak self] wallet in
            self?.didTapBackup?(wallet)
        }
        rootViewModel.onMigration = { [weak self] wallet in
            self?.didTapMigration?(wallet)
        }
        rootViewModel.onRequirePasscode = { [weak self] in
            await self?.getPasscode()
        }
        rootViewModel.onOpenRaffle = { [weak self] in
            self?.openMysteryRaffle()
        }
        rootViewModel.assetsListViewModel.onTapManage = { [weak self, weak rootViewModel] in
            guard
                let self,
                let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet
            else {
                return
            }
            openManageTokens(wallet: wallet, rootViewModel: rootViewModel)
        }
        rootViewModel.assetsListViewModel.onTapOpenAssets = { [weak self] in
            self?.didTapOpenCryptoAssets?()
        }
        rootViewModel.assetsListViewModel.onSelectAsset = { [weak self] asset in
            self?.didSelectMultichainAssetDetails?(
                TradeItemsMapper.previewContext(for: asset)
            )
        }
        rootViewModel.assetsListViewModel.onSelectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStakingInfo in
            self?.didSelectStakingItem?(wallet, stakingPoolInfo, accountStakingInfo)
        }
        rootViewModel.assetsListViewModel.onSelectCollectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStakingInfo in
            self?.didSelectCollectStakingItem?(wallet, stakingPoolInfo, accountStakingInfo)
        }
        rootViewModel.collectiblesViewModel.onTapOpenCollectibles = { [weak self] in
            self?.openCollectibles()
        }
        rootViewModel.collectiblesViewModel.onSelectNFT = { [weak self] nft in
            guard
                let self,
                let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet
            else {
                return
            }
            openNFTDetails(wallet: wallet, nft: nft)
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
        collectiblesCoordinator.didRequestDeeplinkHandling = { [weak self] deeplink in
            self?.collectiblesDidRequestDeeplinkHandling?(deeplink)
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

        coordinator.didRequestDeeplinkHandling = { [weak self] deeplink in
            self?.collectiblesDidRequestDeeplinkHandling?(deeplink)
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

    func openManageTokens(wallet: Wallet, rootViewModel: MultichainWalletRootViewModel?) {
        let coordinator = ManageTokensCoordinator(
            router: router,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            visibilityChangesController: keeperCoreMainAssembly.visibilityChangesController
        )
        coordinator.didSaveVisibilityChanges = { [weak rootViewModel] update in
            guard let rootViewModel else { return }
            rootViewModel.assetsListViewModel.applyVisibilityUpdate(update)
            Task {
                await rootViewModel.reloadAssetsList()
            }
        }
        addChild(coordinator)
        coordinator.didFinish = { [weak self, weak coordinator] _ in
            self?.removeChild(coordinator)
        }

        coordinator.start()
    }
}
