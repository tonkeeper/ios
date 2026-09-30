import BigInt
import KeeperCore
import SafariServices
import Stories
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import TonSwift
import TronSwift
import UIKit

private struct MainHistoryNavigationContext {
    let fromViewController: UINavigationController?
    let routerOrNil: NavigationControllerRouter?
    let presentationStyle: HistoryPresentationStyle
}

final class MainCoordinator: RouterCoordinator<TabBarControllerRouter> {
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    let coreAssembly: TKCore.CoreAssembly
    let mainController: KeeperCore.MainController

    private let mainCoordinatorStateManager: MainCoordinatorStateManager
    var mainCoordinatorStoriesController: MainCoordinatorStoriesController?

    private let walletModule: WalletModule
    private let tradeModule: TradeModule
    private let perpsModule: PerpsModule
    private let historyModule: HistoryModule
    private let browserModule: BrowserModule
    let dappBrowserAnalyticsController: DappBrowserAnalyticsController

    private var walletCoordinator: WalletCoordinator?
    private var multichainWalletCoordinator: MultichainWalletCoordinator?
    private var tradeCoordinator: TradeCoordinator?
    private var standaloneHistoryCoordinator: RouterCoordinator<NavigationControllerRouter>?
    var browserCoordinator: BrowserCoordinator?

    weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
    weak var migrationCoordinator: WalletMigrationCoordinator?

    private weak var addWalletCoordinator: AddWalletCoordinator?
    private weak var importTestnetWalletCoordinator: ImportWalletCoordinator?
    private weak var sendTokenCoordinator: SendCoordinator?
    private weak var webSwapCoordinator: WebSwapCoordinator?
    private weak var batteryRefillCoordinator: BatteryRefillCoordinator?
    private weak var topUpCoordinator: TopUpCoordinator?
    private weak var perpsCoordinator: PerpsCoordinator?
    private weak var stakingCoordinator: StakingCoordinator?
    private weak var stakingStakeCoordinator: StakingStakeCoordinator?
    private weak var stakingUnstakeCoordinator: StakingUnstakeCoordinator?
    private weak var stakingConfirmationCoordinator: StakingConfirmationCoordinator?
    private weak var nativeSwapCoordinator: NativeSwapCoordinator?
    private weak var multichainSwapCoordinator: MultichainSwapCoordinator?

    private let appStateTracker: AppStateTracker
    private let reachabilityTracker: ReachabilityTracker
    let recipientResolver: RecipientResolver
    let insufficientFundsValidator: InsufficientFundsValidator
    private let inAppReviewService: InAppReviewService
    private let cookiesController: KeeperCore.CookiesController

    var deeplinkHandleTask: Task<Void, Never>?
    private(set) var walletConnectState = WalletConnectState()

    private var sendTransactionNotificationToken: NSObjectProtocol?
    private let walletOpenAnalyticsObserver: WalletOpenAnalyticsObserver

    private var modalPresentationDelegate: ModalPresentationDelegate?

    let depositPendingTracker: DepositPendingTracker
    private let tradeAssetDetailsHotWindow: TradeAssetDetailsHotWindow

    private let mysteryRaffleLoadingController: MysteryRaffleLoadingController
    /// The raffle story auto-opens at most once per app session.
    private var didPresentRaffleLaunchStory = false
    /// Holds the raffle's launch story back while the boot configuration's stories play.
    private var isBootConfigurationStoriesRunning = false
    /// External navigation or an explicit story dismissal owns the launch from this point on.
    private var areLaunchStoriesSuppressed = false

    init(
        router: TabBarControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        appStateTracker: AppStateTracker,
        reachabilityTracker: ReachabilityTracker,
        recipientResolver: RecipientResolver,
        insufficientFundsValidator: InsufficientFundsValidator,
        inAppReviewService: InAppReviewService,
        depositPendingTracker: DepositPendingTracker
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.depositPendingTracker = depositPendingTracker
        self.tradeAssetDetailsHotWindow = TradeAssetDetailsHotWindow()
        self.mainController = keeperCoreMainAssembly.mainController()
        self.walletModule = WalletModule(
            dependencies: WalletModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        self.tradeModule = TradeModule(
            dependencies: TradeModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                tradeAssetDetailsHotWindow: tradeAssetDetailsHotWindow
            )
        )
        self.perpsModule = PerpsModule()
        self.historyModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        let dappBrowserAnalyticsController = DappBrowserAnalyticsController(
            analyticsProvider: coreAssembly.analyticsProvider,
            selectedCountryProvider: {
                keeperCoreMainAssembly.storesAssembly.regionStore.getState()
            }
        )
        self.dappBrowserAnalyticsController = dappBrowserAnalyticsController
        self.browserModule = BrowserModule(
            dependencies: BrowserModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                analyticsController: dappBrowserAnalyticsController
            )
        )
        self.appStateTracker = appStateTracker
        self.reachabilityTracker = reachabilityTracker
        self.recipientResolver = recipientResolver
        self.insufficientFundsValidator = insufficientFundsValidator
        self.inAppReviewService = inAppReviewService
        self.mysteryRaffleLoadingController = MysteryRaffleLoadingController(
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            appStateTracker: appStateTracker,
            reachabilityTracker: reachabilityTracker
        )

        self.mainCoordinatorStateManager = MainCoordinatorStateManager(
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore
        )
        self.walletOpenAnalyticsObserver = WalletOpenAnalyticsObserver(
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            analyticsProvider: coreAssembly.analyticsProvider
        )
        cookiesController = CookiesController(
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            cookiesService: keeperCoreMainAssembly.servicesAssembly.cookiesService(),
            tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
        )
        super.init(router: router)

        mainController.didReceiveTonConnectRequest = { [weak self] request, wallet, app in
            self?.handleTonConnectRequest(request, wallet: wallet, app: app)
        }
        cookiesController.start()
        appStateTracker.addObserver(self)
        reachabilityTracker.addObserver(self)

        sendTransactionNotificationToken = NotificationCenter.default
            .addObserver(forName: .transactionSendNotification, object: nil, queue: .main) { [weak self] notification in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let wallet = notification.userInfo?["wallet"] as? Wallet {
                        await keeperCoreMainAssembly.storesAssembly.walletsStore.makeWalletActive(wallet)
                    }
                    guard notification.userInfo?[Notification.transactionSendWithoutHistoryKey] as? Bool != true else {
                        return
                    }
                    openHistory(
                        fromNavigationController: notification.userInfo?[Self.preservePresentedStackKey] as? UINavigationController
                    )
                }
            }

        router.didSelectItem = { [weak self] index in
            guard let self else { return }
            TKTapAnimationHaptic.soft.impactOccurred()
            let viewControllers = self.router.rootViewController.viewControllers ?? []
            guard viewControllers.count > index else { return }
            let viewController = viewControllers[index]
            self.router.rootViewController.playAnimatedTabBarItem(at: index)
            if viewController === self.tradeCoordinator?.router.rootViewController {
                self.coreAssembly.analyticsProvider.log(
                    TradeStarted(from: TradeFlowAnalyticsSource.tabBar.tradeStarted)
                )
                self.coreAssembly.tooltipsAssembly.service.didPerformTooltipTargetAction(id: .tradeTab)
            }
            if viewController === browserCoordinator?.router.rootViewController {
                browserCoordinator?.logBrowserOpen(from: .wallet)
            }
        }

        PushNotificationTapQueue.setHandler { [weak self] userInfo in
            self?.didOpenAppWithPushNotificationTapHandler(userInfo: userInfo)
        }
    }

    deinit {
        if let sendTransactionNotificationToken {
            NotificationCenter.default.removeObserver(sendTransactionNotificationToken)
        }
        walletConnectState.cancel()
        PushNotificationTapQueue.clearHandler()
    }

    override func start(deeplink: CoordinatorDeeplink? = nil) {
        setupChildCoordinators()
        setupTabBarTaps()

        mainCoordinatorStateManager.didUpdateState = { [weak self] state in
            self?.handleStateUpdate(state)
        }
        if let state = try? mainCoordinatorStateManager.getState() {
            handleStateUpdate(state)
        }
        walletOpenAnalyticsObserver.start()
        mainController.start()
        mysteryRaffleLoadingController.start()
        // Before the deeplink dispatch below, so a deeplink or a push arriving on the way in
        // has something to cancel the boot stories on.
        setupStoriesController()
        setupWalletConnectIfNeeded()
        DispatchQueue.main.async {
            _ = self.handleDeeplink(deeplink: deeplink, fromStories: false)
            if case nil = deeplink {
                self.runBootConfigurationStories()
            }
            self.setupRaffleLaunchStory()
        }

        resolveWalletsByPubkey()
    }

    private func resolveWalletsByPubkey() {
        let wallets = keeperCoreMainAssembly.storesAssembly.walletsStore.wallets
        let walletsResolveService = keeperCoreMainAssembly.servicesAssembly.walletsResolveService()

        walletsResolveService.resolveWalletsByPubkey(wallets)
    }

    func handleDeeplink(
        deeplink: CoordinatorDeeplink?,
        fromStories: Bool,
        dappOpenFrom: DappOpenSource = .deepLink,
        utm: UtmParameters = .empty
    ) -> Bool {
        let didHandle: Bool
        switch deeplink {
        case let tonkeeperDeeplink as KeeperCore.Deeplink:
            didHandle = handleTonkeeperDeeplink(
                tonkeeperDeeplink,
                fromStories: fromStories,
                sendSource: .deepLink(utm: utm),
                dappOpenFrom: dappOpenFrom
            )
        case let string as String:
            do {
                let deeplink = try mainController.parseDeeplink(deeplink: string)
                didHandle = handleTonkeeperDeeplink(
                    deeplink,
                    fromStories: fromStories,
                    sendSource: .deepLink(utm: utm.isEmpty ? UtmParameters(link: string) : utm),
                    dappOpenFrom: dappOpenFrom
                )
            } catch let error as DeeplinkParserError where error.isSilent {
                didHandle = true
            } catch {
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: error.localizedDescription))
                didHandle = false
            }
        default:
            didHandle = false
        }
        if didHandle, !fromStories {
            areLaunchStoriesSuppressed = true
            cancelBootConfigurationStories()
        }
        return didHandle
    }

    private func setupStoriesController() {
        let storiesAssembly = Stories.Assembly(
            keeperCoreAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )
        mainCoordinatorStoriesController = MainCoordinatorStoriesController(
            storiesPresenter: storiesAssembly.storiesPresenter(),
            storiesController: storiesAssembly.storiesController()
        )
        mainCoordinatorStoriesController?.fromViewControllerProvider = { [weak self] in self?.router.rootViewController }
        mainCoordinatorStoriesController?.deeplinkAction = { [weak self] in
            _ = self?.handleDeeplink(deeplink: $0, fromStories: true)
        }
        mainCoordinatorStoriesController?.urlAction = { [weak self] in
            self?.openURL($0, title: nil)
        }
    }

    func setupChildCoordinators() {
        let walletCoordinator = walletModule.createWalletCoordinator()
        let multichainWalletCoordinator: MultichainWalletCoordinator? = walletModule
            .createMultichainWalletCoordinator()

        let walletFlows: [WalletTabCoordinatorOutput] = [walletCoordinator, multichainWalletCoordinator]
            .compactMap { $0 }

        for walletFlow in walletFlows {
            walletFlow.didTapScan = { [weak self] in
                self?.openScan()
            }

            walletFlow.didTapWalletButton = { [weak self] in
                self?.coreAssembly.tooltipsAssembly.service.didPerformTooltipTargetAction(id: .addMultichainWalletMain)
                self?.openWalletPicker()
            }

            walletFlow.didTapSwap = { [weak self] wallet in
                self?.openSwap(wallet: wallet, token: .ton(.ton))
            }

            walletFlow.didTapSettingsButton = { [weak self] wallet in
                self?.openSettings(wallet: wallet)
            }

            walletFlow.didTapHistoryButton = { [weak self] in
                guard let self else { return }
                coreAssembly.tooltipsAssembly.service.didPerformTooltipTargetAction(id: .newHistoryEntryPoint)
                openHistory()
            }

            walletFlow.didSelectTonDetails = { [weak self] in
                self?.openTonDetails(wallet: $0)
            }

            walletFlow.didSelectJettonDetails = { [weak self] wallet, jettonItem, hasPrice in
                self?.openJettonDetails(jettonItem: jettonItem, wallet: wallet, hasPrice: hasPrice)
            }

            walletFlow.didSelectTronUSDTDetails = { [weak self] wallet in
                self?.openTronUSDTDetails(wallet: wallet)
            }

            walletFlow.didSelectTronTRXDetails = { [weak self] wallet in
                self?.openTronTRXDetails(wallet: wallet)
            }

            walletFlow.didSelectEthenaDetails = { [weak self] wallet in
                self?.openEthenaDetails(wallet: wallet)
            }

            walletFlow.didSelectStakingItem = { [weak self] wallet, stakingPoolInfo, _ in
                self?.openStakingItemDetails(
                    wallet: wallet,
                    stakingPoolInfo: stakingPoolInfo,
                    initiatedBy: .user
                )
            }

            walletFlow.didSelectCollectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStackingInfo in
                self?.openStakingCollect(
                    wallet: wallet,
                    stakingPoolInfo: stakingPoolInfo,
                    accountStackingInfo: accountStackingInfo,
                    initiatedBy: .user
                )
            }

            walletFlow.didTapDeposit = { [weak self] wallet in
                self?.openDeposit(wallet: wallet, entrySource: .walletScreen)
            }

            walletFlow.didTapSend = { [weak self] wallet in
                self?.openSendWithTokenPicker(
                    wallet: wallet,
                    sendSource: .walletScreen
                )
            }

            walletFlow.didTapWithdraw = { [weak self] wallet in
                self?.openWithdraw(wallet: wallet, entrySource: .walletScreen)
            }

            walletFlow.didTapStake = { [weak self] wallet in
                self?.openStake(wallet: wallet, initiatedBy: .user)
            }

            walletFlow.didTapBackup = { [weak self] wallet in
                self?.openBackup(wallet: wallet, source: .walletSetupSection)
            }

            walletFlow.didTapBattery = { [weak self] wallet in
                self?.openBattery(
                    wallet: wallet,
                    initiatedBy: .user
                )
            }

            walletFlow.didTapOpenCryptoAssets = { [weak self] in
                self?.openCryptoAssetsFromWallet()
            }
        }

        walletCoordinator.collectiblesDidOpenDapp = { [weak self] url, title in
            self?.openDapp(title: title, url: url, analyticsFrom: .collectibles)
        }
        walletCoordinator.collectiblesDidRequestOpenBuySell = { [weak self] isInternalPurchasing, wallet in
            self?.openBuy(wallet: wallet, isInternalPurchasing: isInternalPurchasing, entrySource: .collectibles)
        }
        walletCoordinator.collectiblesDidRequestDepositTon = { [weak self] wallet in
            self?.openDepositTon(wallet: wallet, entrySource: .collectibles)
        }
        walletCoordinator.didRequestDeeplinkHandling = { [weak self] deeplink, utm in
            _ = self?.handleTonkeeperDeeplink(deeplink, fromStories: false, sendSource: .deepLink(utm: utm))
        }
        walletCoordinator.didRequestBannerDeeplinkHandling = { [weak self] deeplink, utm in
            _ = self?.handleTonkeeperDeeplink(
                deeplink,
                fromStories: false,
                sendSource: .deepLink(utm: utm),
                origin: .banner
            )
        }

        let isPerpsEntryPointEnabled = keeperCoreMainAssembly
            .configurationAssembly
            .configuration
            .featureEnabled(.perpsEnabled)

        let tradeCoordinator: TradeCoordinator? = tradeModule.createTradeCoordinator(
            output: TradeModule.CoordinatorOutput(
                onSwap: { [weak self] swapContext, wallet, navigationController in
                    guard let self else { return }
                    switch swapContext {
                    case let .ton(from, to, fromCategory, toCategory):
                        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
                        if configuration.flag(\.nativeSwapDisabled, network: wallet.network) {
                            let address: (TonToken) -> String? = {
                                switch $0 {
                                case let .jetton(item):
                                    item.jettonInfo.address.toRaw()
                                case .ton:
                                    nil
                                }
                            }
                            openWebSwap(
                                wallet: wallet,
                                fromToken: address(from),
                                toToken: address(to),
                                initiatedBy: .user,
                                presentingViewController: navigationController
                            )
                        } else {
                            openNativeSwap(
                                wallet: wallet,
                                nativeSwapContext: NativeSwapContext(
                                    from: .prefetched(.ton(from), category: fromCategory),
                                    to: .prefetched(.ton(to), category: toCategory),
                                    transactionSentNotificationPatch: {
                                        $0[Self.preservePresentedStackKey] = navigationController
                                    }
                                ),
                                initiatedBy: .user,
                                presentingViewController: navigationController
                            )
                        }
                    case .tron:
                        openTRC20Swap()
                    case let .multichain(initialSelection):
                        guard case let .multichain(multichainState) = wallet.multichain else {
                            return
                        }
                        openMultichainSwap(
                            wallet: wallet,
                            multichainState: multichainState,
                            initialSelection: initialSelection,
                            initiatedBy: .user,
                            presentingViewController: navigationController
                        )
                    }
                },
                onSend: { [weak self] wallet, item, navigationController in
                    guard let self else { return }
                    openSendResolvingMultichain(
                        wallet: wallet,
                        sendInput: .direct(item: item),
                        sendSource: .jettonScreen,
                        transactionSentNotificationPatch: {
                            $0[Self.preservePresentedStackKey] = navigationController
                        },
                        comment: nil
                    )
                },
                onSendMultichain: { [weak self] wallet, multichainState, sendInput, navigationController in
                    guard let self else { return }
                    openMultichainSend(
                        wallet: wallet,
                        multichainState: multichainState,
                        entry: .enterAmount(sendInput),
                        sendSource: .jettonScreen,
                        transactionSentNotificationPatch: {
                            $0[Self.preservePresentedStackKey] = navigationController
                        },
                        comment: nil
                    )
                },
                onReceive: { [weak self] token, wallet, _ in
                    guard let self else { return }
                    openReceive(token: token, wallet: wallet)
                },
                onReceiveMultichain: { [weak self] wallet, address, _ in
                    guard let self else { return }
                    openReceive(wallet: wallet, address: address)
                },
                onSellToCard: { [weak self] wallet, assetInfo, resolvedAsset, navigationController in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.openMultichainOfframpFromAsset(
                            wallet: wallet,
                            assetId: assetInfo.assetId,
                            resolvedAsset: resolvedAsset,
                            presentingViewController: navigationController
                        )
                    }
                },
                onCashBuy: { [weak self] wallet, assetInfo, navigationController in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.openMultichainOnrampFromAsset(
                            wallet: wallet,
                            assetId: assetInfo.assetId,
                            presentingViewController: navigationController
                        )
                    }
                },
                onTronUsdtFees: { [weak self] wallet, snapshot, trigger in
                    self?.handleTronUsdtFees(wallet: wallet, snapshot: snapshot, trigger: trigger)
                },
                onOpenStaking: { [weak self] wallet in
                    self?.openStake(wallet: wallet, initiatedBy: .user)
                },
                onOpenPerps: isPerpsEntryPointEnabled ? { [weak self] navigationController in
                    self?.openPerps(on: navigationController)
                } : nil,
                onOpenPerpsMarket: isPerpsEntryPointEnabled ? { [weak self] marketID, navigationController in
                    self?.openPerps(marketID: marketID, on: navigationController)
                } : nil,
                onOpenHistoryEvent: { [weak self] event, navigationController in
                    guard let self else { return }
                    switch event {
                    case let .ton(wallet, event):
                        openHistoryEventDetails(
                            wallet: wallet,
                            event: event,
                            network: wallet.network,
                            fromViewController: navigationController
                        )
                    case let .tron(wallet, event):
                        openTronEventDetails(
                            wallet: wallet,
                            event: event,
                            network: wallet.network,
                            fromViewController: navigationController
                        )
                    }
                },
                tokenDetailsConfiguratorProvider: { [weak self] wallet, token in
                    self?.makeTokenDetailsConfigurator(
                        wallet: wallet,
                        token: token
                    )
                },
                onOpenUnverifiedTokenInfoPopup: { [weak self] _ in
                    guard let self else { return }
                    openUnverifiedTokenInfoPopup()
                },
                onOpenVerifiedTokenInfoPopup: { [weak self] _ in
                    guard let self else { return }
                    openVerifiedTokenInfoPopup()
                },
                onOpenUrl: { [weak self] url, navigationController in
                    guard let self else { return }
                    if let navigationController {
                        navigationController.modalPresentationSourceViewController().present(
                            bridgeViewController(for: url, title: nil),
                            animated: true
                        )
                    } else {
                        openURL(url, title: nil)
                    }
                }
            )
        )

        let browserCoordinator = browserModule.createBrowserCoordinator()

        browserCoordinator.didHandleDeeplink = { [weak self] deeplink, utm in
            _ = self?.handleTonkeeperDeeplink(deeplink, fromStories: false, sendSource: .deepLink(utm: utm))
        }

        browserCoordinator.didRequestOpenBuySell = { [weak self] wallet in
            self?.openBuy(wallet: wallet, entrySource: .browser)
        }

        self.walletCoordinator = walletCoordinator
        self.multichainWalletCoordinator = multichainWalletCoordinator
        self.tradeCoordinator = tradeCoordinator
        self.browserCoordinator = browserCoordinator

        multichainWalletCoordinator?.collectiblesDidOpenDapp = { [weak self] url, title in
            self?.openDapp(title: title, url: url, analyticsFrom: .collectibles)
        }
        multichainWalletCoordinator?.collectiblesDidRequestDeeplinkHandling = { [weak self] deeplink, utm in
            _ = self?.handleTonkeeperDeeplink(deeplink, fromStories: false, sendSource: .deepLink(utm: utm))
        }
        multichainWalletCoordinator?.didRequestBannerDeeplinkHandling = { [weak self] deeplink, utm in
            _ = self?.handleTonkeeperDeeplink(
                deeplink,
                fromStories: false,
                sendSource: .deepLink(utm: utm),
                origin: .banner
            )
        }
        multichainWalletCoordinator?.collectiblesDidRequestOpenBuySell = { [weak self] isInternalPurchasing, wallet in
            self?.openBuy(wallet: wallet, isInternalPurchasing: isInternalPurchasing, entrySource: .collectibles)
        }
        multichainWalletCoordinator?.collectiblesDidRequestDepositTon = { [weak self] wallet in
            self?.openDepositTon(wallet: wallet, entrySource: .collectibles)
        }
        multichainWalletCoordinator?.didRequestDeeplinkHandling = { [weak self] deeplink in
            self?.handleRaffleDeeplink(deeplink)
        }
        multichainWalletCoordinator?.didRequestOpenMigration = { [weak self] onFinish in
            self?.openMigrationDeeplink(source: .raffle, onFinish: onFinish)
        }
        multichainWalletCoordinator?.didTapMigration = { [weak self] _ in
            self?.openMigrationDeeplink(source: .setup)
        }
        multichainWalletCoordinator?.didTapAddress = { [weak self] wallet in
            guard let self else { return }
            openReceive(tokens: getRampTokens(wallet: wallet), wallet: wallet)
        }
        tradeCoordinator?.didRequestDeeplinkHandling = { [weak self] deeplink in
            self?.handleRaffleDeeplink(deeplink)
        }
        tradeCoordinator?.didRequestOpenMigration = { [weak self] onFinish in
            self?.openMigrationDeeplink(source: .raffle, onFinish: onFinish)
        }

        multichainWalletCoordinator?.didSelectMultichainAssetDetails = { [weak self] preview in
            guard let self else { return }
            guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
                  wallet.network.isMainnet,
                  let tradeCoordinator = self.tradeCoordinator
            else {
                return
            }
            let navigationController = router.rootViewController.navigationController
            guard let navigationController else {
                return
            }
            tradeCoordinator.openAssetDetails(
                preview: preview,
                on: navigationController,
                source: .walletScreen
            )
        }

        if let multichainWalletCoordinator {
            addChild(multichainWalletCoordinator)
        }
        addChild(walletCoordinator)
        tradeCoordinator.flatMap(addChild)
        addChild(browserCoordinator)

        multichainWalletCoordinator?.start()
        walletCoordinator.start()
        tradeCoordinator?.start()
        browserCoordinator.start()
    }

    private func makeTronDetailsConfigurator(
        wallet: Wallet
    ) -> TronUSDTTokenDetailsConfigurator {
        let mapper = TokenDetailsMapper(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            rateConverter: RateConverter()
        )
        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration

        let configurator = TronUSDTTokenDetailsConfigurator(
            wallet: wallet,
            mapper: mapper,
            configuration: configuration,
            feesSnapshotService: keeperCoreMainAssembly.servicesAssembly.tronUSDTFeesService,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            buySellMethodsService: keeperCoreMainAssembly.buySellAssembly.buySellMethodsService()
        )

        configurator.didTapBanner = { [weak self] snapshot in
            if snapshot.isTRXOnlyRegion {
                self?.openReceive(token: .tron(.trx), wallet: wallet)
            } else {
                self?.openUsdtFees(wallet: wallet, snapshot: snapshot, reason: .topup)
            }
        }
        configurator.didTapTransfersAvailable = { [weak self] snapshot in
            self?.openUsdtFees(wallet: wallet, snapshot: snapshot, reason: .topup)
        }

        return configurator
    }

    private func makeTokenDetailsConfigurator(
        wallet: Wallet,
        token: Token
    ) -> TokenDetailsConfigurator {
        let mapper = TokenDetailsMapper(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            rateConverter: RateConverter()
        )
        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration

        switch token {
        case .ton(.ton):
            return TonTokenDetailsConfigurator(
                wallet: wallet,
                mapper: mapper,
                configuration: configuration
            )
        case let .ton(.jetton(jettonItem)):
            return JettonTokenDetailsConfigurator(
                wallet: wallet,
                jettonItem: jettonItem,
                mapper: mapper,
                configuration: configuration,
                onShowUnverifiedTokenInfo: { [weak self] in
                    self?.openUnverifiedTokenInfoPopup()
                }
            )
        case .tron:
            return makeTronDetailsConfigurator(wallet: wallet)
        }
    }

    private func createStandaloneHistoryCoordinator(
        navigationController: UINavigationController? = nil
    ) -> RouterCoordinator<NavigationControllerRouter>? {
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
            return nil
        }

        let navigationContext = createHistoryNavigationContext(navigationController: navigationController)
        return createHistoryCoordinatorFactory().makeCoordinator(
            wallet: wallet,
            router: navigationContext.routerOrNil,
            presentationStyle: navigationContext.presentationStyle,
            fromViewController: navigationContext.fromViewController
        )
    }

    private func createHistoryCoordinatorFactory() -> MainHistoryCoordinatorFactory {
        MainHistoryCoordinatorFactory(
            historyModule: historyModule,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            output: MainHistoryCoordinatorFactory.Output(
                didOpenTonEventDetails: { [weak self] wallet, event, network, fromViewController in
                    self?.openHistoryEventDetails(
                        wallet: wallet,
                        event: event,
                        network: network,
                        fromViewController: fromViewController
                    )
                },
                didOpenTronEventDetails: { [weak self] wallet, event, network, fromViewController in
                    self?.openTronEventDetails(
                        wallet: wallet,
                        event: event,
                        network: network,
                        fromViewController: fromViewController
                    )
                },
                didDecryptComment: { [weak self] wallet, payload, eventId in
                    self?.decryptComment(wallet: wallet, payload: payload, eventId: eventId)
                },
                didOpenDapp: { [weak self] url, title in
                    self?.openDapp(
                        title: title,
                        url: url,
                        analyticsFrom: .history
                    )
                },
                didTapAddFunds: { [weak self] wallet in
                    self?.openDeposit(wallet: wallet, entrySource: .historyScreen)
                },
                didRequestDepositTon: { [weak self] wallet in
                    self?.openDepositTon(wallet: wallet, entrySource: .historyScreen)
                }
            )
        )
    }

    private func createHistoryNavigationContext(navigationController: UINavigationController? = nil) -> MainHistoryNavigationContext {
        let fromViewController = navigationController ?? router.rootViewController.navigationController
        let routerOrNil = fromViewController.map(NavigationControllerRouter.init(rootViewController:))
        let presentationStyle: HistoryPresentationStyle = .push(
            closeAction: { [weak fromViewController] in
                fromViewController?.popViewController(animated: true)
            }
        )

        return MainHistoryNavigationContext(
            fromViewController: fromViewController,
            routerOrNil: routerOrNil,
            presentationStyle: presentationStyle
        )
    }

    func handleStateUpdate(_ state: MainCoordinatorStateManager.State) {
        let viewControllers = state.tabs.compactMap { tab -> RouterCoordinator<NavigationControllerRouter>? in
            switch tab {
            case .wallet:
                walletTabNavigationCoordinator()
            case .trade:
                tradeCoordinator
            case .browser:
                browserCoordinator
            }
        }.map { $0.router.rootViewController }

        router.rootViewController.setViewControllers(viewControllers, animated: false)
        setupAnimatedTabs(with: state)
        DispatchQueue.main.async { [weak self] in
            self?.showEntryPointTooltipsIfNeeded(with: state)
        }
    }

    @MainActor
    private func setupAnimatedTabs(with state: MainCoordinatorStateManager.State) {
        router.rootViewController.configureAnimatedTabBarItems(
            items: state.tabs
        )
    }

    func setupTabBarTaps() {
        (router.rootViewController as? TKTabBarController)?.didLongPressTabBarItem = { [weak self] index in
            guard index == 0 else { return }
            self?.openWalletPicker()
        }
    }

    @MainActor
    private func showEntryPointTooltipsIfNeeded(with state: MainCoordinatorStateManager.State) {
        showNewHistoryEntryPointTooltipIfNeeded()
        showTradeTabTooltipIfNeeded(with: state)
        showAddMultichainWalletMainTooltipIfNeeded()
    }

    @MainActor
    private func showNewHistoryEntryPointTooltipIfNeeded() {
        walletTabCoordinatorOutput()?.historyButtonTooltipSourceView { [weak self] sourceView in
            self?.coreAssembly.tooltipsAssembly.service.showTooltipIfNeeded(
                id: .newHistoryEntryPoint,
                sourceView: sourceView,
                targetActionViews: [sourceView],
                configuration: HintConfiguration(
                    position: HintPosition(
                        tailParameters: TKTooltipView.tailParameters,
                        horizontal: .default,
                        vertical: .init(absolute: 0),
                        direction: .bottomRight
                    ),
                    maximumWidth: 280,
                    animationStyle: .bouncing
                )
            )
        }
    }

    @MainActor
    private func showAddMultichainWalletMainTooltipIfNeeded() {
        guard shouldShowAddMultichainWalletTooltip else { return }

        walletTabCoordinatorOutput()?.walletButtonTooltipSourceView { [weak self] sourceView in
            guard let self else { return }
            coreAssembly.tooltipsAssembly.service.showTooltipIfNeeded(
                id: .addMultichainWalletMain,
                sourceView: sourceView,
                targetActionViews: [sourceView],
                configuration: HintConfiguration(
                    position: HintPosition(
                        tailParameters: TKTooltipView.tailParameters,
                        horizontal: .default,
                        vertical: .init(absolute: 0),
                        direction: .bottomCenter
                    ),
                    maximumWidth: AddMultichainWalletTooltipLayout.maximumWidth,
                    animationStyle: .bouncing
                ),
                onTargetAction: { [weak self] in
                    self?.openWalletPicker()
                }
            )
        }
    }

    private var shouldShowAddMultichainWalletTooltip: Bool {
        keeperCoreMainAssembly.storesAssembly.walletsStore.wallets.filter(\.isMultichain).isEmpty
    }

    @MainActor
    private func showTradeTabTooltipIfNeeded(with state: MainCoordinatorStateManager.State) {
        guard let tradeIndex = state.tabs.firstIndex(of: .trade) else { return }

        router.rootViewController.tabBar.layoutIfNeeded()

        guard let tabBarController = router.rootViewController as? TKTabBarController,
              let sourceView = tabBarController.tabBarItemView(at: tradeIndex)
        else {
            return
        }

        coreAssembly.tooltipsAssembly.service.showTooltipIfNeeded(
            id: .tradeTab,
            sourceView: sourceView,
            targetActionViews: [sourceView],
            configuration: HintConfiguration(
                position: HintPosition(
                    tailParameters: TKTooltipView.tailParameters,
                    horizontal: .default,
                    vertical: .init(absolute: 0),
                    direction: .topRight
                ),
                maximumWidth: 280,
                animationStyle: .bouncing
            )
        )
    }

    func openScan() {
        let extensions = keeperCoreMainAssembly.configurationAssembly.configuration.value(\.qrScannerExtensions)
        let scannerAssembly = keeperCoreMainAssembly.scannerAssembly()
        let scanModule = ScannerModule(
            dependencies: ScannerModule.Dependencies(
                coreAssembly: coreAssembly,
                scannerAssembly: scannerAssembly
            )
        ).createScannerModule(
            configurator: DefaultScannerControllerConfigurator(
                extensions: extensions ?? [],
                deeplinkParser: scannerAssembly.deeplinkParser,
                isMultichainEnabled: isActiveWalletMultichain
            ),
            uiConfiguration: ScannerUIConfiguration(
                title: TKLocales.Scanner.title,
                subtitle: nil,
                isFlashlightVisible: true
            )
        )

        let navigationController = TKNavigationController(rootViewController: scanModule.view)
        navigationController.configureTransparentAppearance()

        scanModule.output.didScanDeeplink = { [weak self] deeplink in
            self?.router.dismiss(completion: {
                _ = self?.handleTonkeeperDeeplink(
                    deeplink,
                    fromStories: false,
                    sendSource: .qrCode
                )
            })
        }

        scanModule.output.didFailScan = { [weak self] error, shouldDismiss in
            ToastPresenter.hideAll()
            guard let error else { return }
            ToastPresenter.showToast(configuration: .init(title: error))
            if shouldDismiss {
                self?.router.dismiss()
            }
        }

        router.present(navigationController)
    }

    func openSend(
        wallet: Wallet,
        sendInput: SendInput,
        sendSource: SendAnalyticsSource,
        transactionSentNotificationPatch: @Sendable @escaping (inout [String: Any]) -> Void = { _ in },
        recipient: LegacyRecipient? = nil,
        comment: String?,
        successReturn: URL? = nil
    ) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let sendTokenCoordinator = SendModule(
            dependencies: SendModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createSendTokenCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet,
            sendInput: sendInput,
            sendSource: sendSource,
            transactionSentNotificationPatch: transactionSentNotificationPatch,
            recipient: recipient,
            comment: comment
        )

        sendTokenCoordinator.didFinish = { [weak self, weak navigationController] in
            self?.sendTokenCoordinator = nil
            navigationController?.dismiss(animated: true)
            self?.removeChild($0)
        }

        sendTokenCoordinator.didSendSuccessfully = { [weak self, weak navigationController] in
            self?.sendTokenCoordinator = nil
            navigationController?.dismiss(animated: true, completion: { [weak self] in
                self?.inAppReviewService.trackSuccessfulSend()
                guard let successReturn else { return }
                self?.openURL(successReturn, title: nil)
            })
            self?.removeChild($0)
        }

        sendTokenCoordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            guard let self else { return }
            openBuy(
                wallet: wallet,
                isInternalPurchasing: isInternalPurchasing,
                entrySource: depositAnalyticsSource(for: sendSource)
            )
        }
        sendTokenCoordinator.didRequestRefill = { [weak self] token, onRefill in
            self?.openFeeRefill(token: token, wallet: wallet, onRefill: onRefill)
        }
        sendTokenCoordinator.didRequestOpenBattery = { [weak self] onRechargeSuccess in
            self?.openBattery(
                wallet: wallet,
                keepCurrentModal: true,
                initiatedBy: sendSource.initiatedBy,
                onRechargeSuccess: onRechargeSuccess
            )
        }

        self.sendTokenCoordinator = sendTokenCoordinator

        addChild(sendTokenCoordinator)

        sendTokenCoordinator.start()

        router.presentOverTopPresented(
            navigationController,
            animated: true,
            completion: nil
        ) { [weak self, weak sendTokenCoordinator] in
            self?.sendTokenCoordinator = nil
            guard let sendTokenCoordinator else { return }
            self?.removeChild(sendTokenCoordinator)
        }
    }

    func openMultichainSend(
        wallet: Wallet,
        multichainState: MultichainWalletState,
        entry: MultichainSendEntry,
        sendSource: SendAnalyticsSource,
        transactionSentNotificationPatch: @Sendable @escaping (inout [String: Any]) -> Void = { _ in },
        recipient: MultichainRecipient? = nil,
        comment: String?,
        successReturn: URL? = nil
    ) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        guard let sendTokenCoordinator = SendModule(
            dependencies: SendModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createMultichainSendCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet,
            multichainState: multichainState,
            entry: entry,
            sendSource: sendSource,
            transactionSentNotificationPatch: transactionSentNotificationPatch,
            recipient: recipient,
            comment: comment
        ) else {
            return
        }

        sendTokenCoordinator.didFinish = { [weak self, weak navigationController] in
            self?.sendTokenCoordinator = nil
            navigationController?.dismiss(animated: true)
            self?.removeChild($0)
        }

        sendTokenCoordinator.didSendSuccessfully = { [weak self, weak navigationController] in
            self?.sendTokenCoordinator = nil
            navigationController?.dismiss(animated: true, completion: { [weak self] in
                self?.inAppReviewService.trackSuccessfulSend()
                guard let successReturn else { return }
                self?.openURL(successReturn, title: nil)
            })
            self?.removeChild($0)
        }

        sendTokenCoordinator.didRequestRefill = { [weak self] token, onRefill in
            self?.openFeeRefill(token: token, wallet: wallet, onRefill: onRefill)
        }
        sendTokenCoordinator.didRequestOpenBattery = { [weak self] onRechargeSuccess in
            self?.openBattery(
                wallet: wallet,
                keepCurrentModal: true,
                initiatedBy: sendSource.initiatedBy,
                onRechargeSuccess: onRechargeSuccess
            )
        }
        sendTokenCoordinator.didRequestFeeDeposit = { [weak self, weak navigationController] assetId, onDismiss in
            guard let self, let navigationController else { return }
            Task {
                await self.openMultichainOnrampFromAsset(
                    wallet: wallet,
                    assetId: assetId,
                    presentingViewController: navigationController,
                    onDismiss: onDismiss,
                    onUnavailable: {
                        self.openReceiveForFeeAsset(assetId: assetId, wallet: wallet, onClose: onDismiss)
                    }
                )
            }
        }

        self.sendTokenCoordinator = sendTokenCoordinator

        addChild(sendTokenCoordinator)

        sendTokenCoordinator.start()

        router.presentOverTopPresented(
            navigationController,
            animated: true,
            completion: nil
        ) { [weak self, weak sendTokenCoordinator] in
            self?.sendTokenCoordinator = nil
            guard let sendTokenCoordinator else { return }
            self?.removeChild(sendTokenCoordinator)
        }
    }

    func openSendPushedOnto(
        wallet: Wallet,
        sendInput: SendInput,
        sendSource: SendAnalyticsSource,
        comment: String?,
        pushRouter: NavigationControllerRouter
    ) {
        let sendTokenCoordinator = SendModule(
            dependencies: SendModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createSendTokenCoordinator(
            router: pushRouter,
            wallet: wallet,
            sendInput: sendInput,
            sendSource: sendSource,
            recipient: nil,
            comment: comment
        )

        sendTokenCoordinator.didFinish = { [weak self, weak pushRouter] in
            self?.sendTokenCoordinator = nil
            pushRouter?.rootViewController.dismiss(animated: true)
            self?.removeChild($0)
        }

        sendTokenCoordinator.didSendSuccessfully = { [weak self, weak pushRouter] in
            self?.sendTokenCoordinator = nil
            pushRouter?.rootViewController.popViewController(animated: true)
            self?.removeChild($0)
            self?.inAppReviewService.trackSuccessfulSend()
            self?.openHistory()
        }

        sendTokenCoordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            guard let self else { return }
            openBuy(
                wallet: wallet,
                isInternalPurchasing: isInternalPurchasing,
                entrySource: depositAnalyticsSource(for: sendSource)
            )
        }
        sendTokenCoordinator.didRequestRefill = { [weak self] token, onRefill in
            self?.openFeeRefill(token: token, wallet: wallet, onRefill: onRefill)
        }
        sendTokenCoordinator.didRequestOpenBattery = { [weak self] onRechargeSuccess in
            self?.openBattery(
                wallet: wallet,
                keepCurrentModal: true,
                initiatedBy: sendSource.initiatedBy,
                onRechargeSuccess: onRechargeSuccess
            )
        }

        self.sendTokenCoordinator = sendTokenCoordinator

        addChild(sendTokenCoordinator)

        sendTokenCoordinator.start(pushAnimated: true)
    }

    func openSwap(wallet: Wallet, token: Token) {
        switch token {
        case let .ton(tonToken):
            let fromToken: String?
            let toToken: String?
            switch tonToken {
            case .ton:
                fromToken = TonInfo.symbol
                toToken = nil
            case let .jetton(jetton):
                fromToken = jetton.jettonInfo.address.toRaw()
                if jetton.jettonInfo.address == JettonMasterAddress.USDe {
                    toToken = JettonMasterAddress.tonUSDT.toRaw()
                } else if jetton.jettonInfo.address == JettonMasterAddress.tsUSDe {
                    toToken = JettonMasterAddress.USDe.toRaw()
                } else {
                    toToken = TonInfo.symbol
                }
            }

            let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
            if configuration.flag(\.nativeSwapDisabled, network: wallet.network) {
                openWebSwap(
                    wallet: wallet,
                    fromToken: fromToken,
                    toToken: toToken,
                    initiatedBy: .user
                )
            } else {
                if let state = wallet.multichainWalletState {
                    openMultichainSwap(
                        wallet: wallet,
                        multichainState: state,
                        nativeSwapContext: NativeSwapContext(
                            fromTokenAddress: fromToken,
                            toTokenAddress: toToken
                        ),
                        initiatedBy: .user
                    )
                } else {
                    openNativeSwap(
                        wallet: wallet,
                        nativeSwapContext: NativeSwapContext(
                            fromTokenAddress: fromToken,
                            toTokenAddress: toToken
                        ),
                        initiatedBy: .user
                    )
                }
            }
        case .tron:
            openTRC20Swap()
        }
    }

    func openMultichainSwap(
        wallet: Wallet,
        multichainState: MultichainWalletState,
        nativeSwapContext: NativeSwapContext = NativeSwapContext(),
        initialSelection: MultichainSwapInitialAssetSelection? = nil,
        initiatedBy: InitiatedBy,
        presentingViewController: UIViewController? = nil
    ) {
        let navigationController = TKNavigationController()
        navigationController.configureDefaultAppearance()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = MultichainSwapCoordinator(
            wallet: wallet,
            multichainState: multichainState,
            nativeSwapContext: nativeSwapContext,
            initialSelection: initialSelection,
            initiatedBy: initiatedBy,
            router: NavigationControllerRouter(rootViewController: navigationController),
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        multichainSwapCoordinator = coordinator

        coordinator.didRequestDeeplinkHandling = { [weak self] in
            self?.handleRaffleDeeplink($0)
        }

        coordinator.didRequestOpenMigration = { [weak self] onFinish in
            self?.openMigrationDeeplink(source: .raffle, onFinish: onFinish)
        }

        coordinator.didFinish = { [weak self, weak coordinator, weak navigationController] _ in
            guard let self, let coordinator else { return }

            navigationController?.dismiss(animated: true)
            removeChild(coordinator)
        }

        coordinator.didSwapSuccessfully = { [weak self, weak coordinator, weak navigationController] in
            guard let self else { return }

            removeChild(coordinator)
            guard let navigationController else {
                openHistory()
                return
            }

            navigationController.dismiss(animated: true) { [weak self] in
                self?.openHistory()
            }
        }

        coordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            guard let self else { return }

            openBuy(
                wallet: wallet,
                isInternalPurchasing: isInternalPurchasing,
                entrySource: depositAnalyticsSource(for: initiatedBy)
            )
        }

        coordinator.didRequestFeeDeposit = { [weak self, weak navigationController] assetId, onDismiss in
            guard let self, let navigationController else { return }
            Task {
                await self.openMultichainOnrampFromAsset(
                    wallet: wallet,
                    assetId: assetId,
                    presentingViewController: navigationController,
                    onDismiss: onDismiss,
                    onUnavailable: {
                        self.openReceiveForFeeAsset(assetId: assetId, wallet: wallet, onClose: onDismiss)
                    }
                )
            }
        }

        coordinator.didRequestOpenBattery = { [weak self] onRechargeSuccess in
            self?.openBattery(
                wallet: wallet,
                keepCurrentModal: true,
                initiatedBy: initiatedBy,
                onRechargeSuccess: onRechargeSuccess
            )
        }

        addChild(coordinator)
        coordinator.start()

        if let presentingViewController {
            presentModally(
                navigationController,
                from: presentingViewController,
                onDismiss: { [weak self, weak coordinator] in
                    self?.removeChild(coordinator)
                }
            )
        } else {
            router.dismiss(animated: true) { [weak self, weak coordinator] in
                self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                    self?.removeChild(coordinator)
                })
            }
        }
    }

    func openNativeSwap(
        wallet: Wallet,
        nativeSwapContext: NativeSwapContext = NativeSwapContext(),
        initiatedBy: InitiatedBy,
        presentingViewController: UIViewController? = nil
    ) {
        let navigationController = TKNavigationController()
        navigationController.configureDefaultAppearance()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = NativeSwapModule(
            dependencies: NativeSwapModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).swapCoordinator(
            wallet: wallet,
            nativeSwapContext: nativeSwapContext,
            initiatedBy: initiatedBy,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )

        nativeSwapCoordinator = coordinator

        coordinator.didFinish = { [weak self, weak coordinator, weak navigationController] _ in
            guard let self, let coordinator else { return }

            navigationController?.dismiss(animated: true)
            removeChild(coordinator)
        }

        coordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            guard let self else { return }

            openBuy(
                wallet: wallet,
                isInternalPurchasing: isInternalPurchasing,
                entrySource: depositAnalyticsSource(for: initiatedBy)
            )
        }

        addChild(coordinator)
        coordinator.start()

        if let presentingViewController {
            presentModally(
                navigationController,
                from: presentingViewController,
                onDismiss: { [weak self, weak coordinator] in
                    self?.removeChild(coordinator)
                }
            )
        } else {
            router.dismiss(animated: true) { [weak self, weak coordinator] in
                self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                    self?.removeChild(coordinator)
                })
            }
        }
    }

    func openPerps(on navigationController: UINavigationController?) {
        openPerps(marketID: nil, on: navigationController)
    }

    func openPerps(marketID: Int64?, on navigationController: UINavigationController?) {
        guard perpsCoordinator == nil,
              let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
              wallet.isMultichain
        else {
            return
        }

        let targetNavigationController: UINavigationController
        if let navigationController {
            targetNavigationController = navigationController.tabBarHostNavigationController
        } else if let selectedNavigationController = router.rootViewController.selectedViewController as? UINavigationController {
            targetNavigationController = selectedNavigationController.tabBarHostNavigationController
        } else {
            return
        }

        let coordinator = perpsModule.createPerpsCoordinator(
            router: NavigationControllerRouter(rootViewController: targetNavigationController),
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            walletScope: keeperCoreMainAssembly.perpsAssembly.makeWalletScope(for: wallet),
            analyticsProvider: coreAssembly.analyticsProvider
        )
        perpsCoordinator = coordinator
        coordinator.didFinish = { [weak self] finished in
            guard let self else { return }
            self.removeChild(finished)
            if self.perpsCoordinator === finished {
                self.perpsCoordinator = nil
            }
        }
        addChild(coordinator)
        coordinator.start(marketID: marketID)
    }

    func openWebSwap(
        wallet: Wallet,
        fromToken: String? = nil,
        toToken: String? = nil,
        initiatedBy: InitiatedBy,
        utm: UtmParameters = .empty,
        presentingViewController: UIViewController? = nil
    ) {
        let navigationController = TKNavigationController()
        navigationController.configureDefaultAppearance()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = WebSwapModule(
            dependencies: WebSwapModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).swapCoordinator(
            wallet: wallet,
            fromToken: fromToken,
            toToken: toToken,
            initiatedBy: initiatedBy,
            utm: utm,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )

        coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
            navigationController?.dismiss(animated: true)
            guard let coordinator else { return }

            self?.removeChild(coordinator)
        }

        self.webSwapCoordinator = coordinator

        addChild(coordinator)
        coordinator.start()

        if let presentingViewController {
            presentModally(
                navigationController,
                from: presentingViewController,
                onDismiss: { [weak self, weak coordinator] in
                    self?.removeChild(coordinator)
                }
            )
        } else {
            router.dismiss(animated: true) { [weak self, weak coordinator] in
                self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                    self?.removeChild(coordinator)
                })
            }
        }
    }

    private var trc20SwapOpenTask: Task<Void, Swift.Error>?
    func openTRC20Swap() {
        trc20SwapOpenTask?.cancel()
        trc20SwapOpenTask = Task { [weak self] in
            guard let self else { return }

            let service = keeperCoreMainAssembly.buySellAssembly.buySellMethodsService()
            guard let methods = try? await service.loadFiatMethods(
                countryCode: nil,
                walletId: activeWalletScopeId
            ) else { return }

            if Task.isCancelled {
                return
            }

            guard let url = methods.buy
                .flatMap(\.items)
                .first(where: { $0.id == "letsexchange_buy_swap" })
                .flatMap({ URL(string: $0.actionButton.url) })
            else { return }

            openURL(url, title: nil)
        }
    }

    func handleTonkeeperDeeplink(
        _ deeplink: KeeperCore.Deeplink,
        fromStories: Bool,
        sendSource: SendAnalyticsSource,
        origin: DeeplinkOrigin = .app,
        dappOpenFrom: DappOpenSource = .deepLink
    ) -> Bool {
        let utm = sendSource.utm
        switch deeplink {
        case let .transfer(data):
            switch data {
            case let .sendTransfer(sendTransferData):
                openSendDeeplink(
                    transfer: sendTransferData,
                    sendSource: sendSource
                )
                return true
            case let .multichainSendTransfer(candidates):
                openMultichainSendDeeplink(
                    candidates: candidates,
                    sendSource: sendSource
                )
                return true
            case let .evmSendTransfer(evmTransferData):
                openEvmSendDeeplink(
                    transfer: evmTransferData,
                    sendSource: sendSource
                )
                return true
            case let .signRawTransfer(signRawTransferData):
                openSignRawSendDeeplink(
                    recipient: signRawTransferData.recipient,
                    jettonMaster: signRawTransferData.jettonAddress,
                    amount: signRawTransferData.amount,
                    bin: signRawTransferData.bin,
                    stateInit: signRawTransferData.stateInit,
                    expirationTimestamp: signRawTransferData.expirationTimestamp,
                    sendSource: sendSource
                )
                return true
            }
        case .staking:
            openStakingDeeplink(utm: utm)
            return true
        case let .pool(poolAddress):
            openPoolDetailsDeeplink(poolAddress: poolAddress, utm: utm)
            return true
        case let .swap(data):
            openSwapDeeplink(fromToken: data.fromToken, toToken: data.toToken, utm: utm)
            return true
        case let .action(eventId):
            openActionDeeplink(eventId: eventId)
            return true
        case let .publish(sign):
            if let walletTransferSignCoordinator {
                walletTransferSignCoordinator.externalSignHandler?(sign)
                walletTransferSignCoordinator.externalSignHandler = nil
                return true
            }
            if let sendTokenCoordinator = sendTokenCoordinator {
                return sendTokenCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
            }
            if handleWalletCollectiblesPublishDeeplink(sign: sign) {
                return true
            }
            if let webSwapCoordinator = webSwapCoordinator,
               webSwapCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
            {
                return true
            }
            if let nativeSwapCoordinator = nativeSwapCoordinator,
               nativeSwapCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
            {
                return true
            }
            if let multichainSwapCoordinator = multichainSwapCoordinator,
               multichainSwapCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
            {
                return true
            }
            if let batteryRefillCoordinator,
               batteryRefillCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
            {
                return true
            }
            if let stakingCoordinator,
               stakingCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
            {
                return true
            }
            if let stakingStakeCoordinator,
               stakingStakeCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
            {
                return true
            }
            if let stakingUnstakeCoordinator,
               stakingUnstakeCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
            {
                return true
            }
            if let stakingConfirmationCoordinator,
               stakingConfirmationCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
            {
                return true
            }
            return false
        case let .externalSign(data):
            return handleSignerDeeplink(data)
        case let .tonconnect(parameters):
            return handleTonConnectDeeplink(parameters)
        case let .walletConnect(payload):
            return handleWalletConnectDeeplink(payload)
        case let .dapp(dappURL):
            return handleDappDeeplink(url: dappURL, analyticsFrom: dappOpenFrom, utm: utm)
        case let .browser(network):
            openBrowserTabExplore(network: network)
            browserCoordinator?.logBrowserOpen(
                from: fromStories ? .story : .deepLink,
                utm: utm
            )
            return true
        case .migration:
            openMigrationDeeplink(source: migrationSource(fromStories: fromStories, origin: origin))
            return true
        case let .trading(gridID):
            return openTradingDeeplink(
                gridID: gridID,
                source: tradeFlowAnalyticsSource(for: sendSource)
            )
        case let .tradeAsset(assetID):
            return openTradeAssetDeeplink(
                assetID: assetID,
                source: assetViewAnalyticsSource(for: sendSource)
            )
        case let .battery(battery):
            handleBatteryDeeplink(battery, utm: utm)
            return true
        case let .story(storyId):
            handleStoryDeeplink(storyId: storyId)
            return true
        case .receive:
            openReceiveDeeplink()
            return true
        case .backup:
            openBackupDeeplink()
            return true
        case .addWallet:
            openAddWalletDeeplink()
            return true
        case .main:
            openMainDeeplink()
            return true
        case .raffle:
            openMysteryRaffleDeeplink()
            return true
        case let .deposit(parameters):
            openRampDeeplink(
                flow: .deposit,
                parameters: parameters,
                entrySource: depositAnalyticsSource(for: sendSource),
                utm: utm
            )
            return true
        case let .withdraw(parameters):
            openRampDeeplink(
                flow: .withdraw,
                parameters: parameters,
                entrySource: depositAnalyticsSource(for: sendSource),
                utm: utm
            )
            return true
        }
    }

    // MARK: -  TODO: complete on next iteration: flow: .deeplink

    func handleTonConnectDeeplink(_ payload: TonConnectPayload) -> Bool {
        switch payload {
        case .empty:
            return false
        case let .withParameters(parameters, _):
            return handleTonConnectDeeplink(parameters: parameters)
        }
    }

    private func handleTonConnectDeeplink(parameters: TonConnectParameters) -> Bool {
        let tonConnectService = keeperCoreMainAssembly.tonConnectAssembly.tonConnectService()

        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)
        guard let windowScene = router.rootViewController.windowScene else {
            return false
        }
        let window = TKWindow(windowScene: windowScene)
        window.windowLevel = .tonConnectConnect
        let router = WindowRouter(window: window)
        Task { [self] in
            switch await tonConnectService.loadAppManifest(parameters: parameters) {
            case let .success(manifest):
                await MainActor.run {
                    ToastPresenter.hideToast()
                    let coordinator = TonConnectModule(
                        dependencies: TonConnectModule.Dependencies(
                            coreAssembly: coreAssembly,
                            keeperCoreMainAssembly: keeperCoreMainAssembly
                        )
                    ).createConnectCoordinator(
                        router: router,
                        flow: .common,
                        connector: DefaultTonConnectConnectCoordinatorConnector(
                            tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
                        ),
                        parameters: parameters,
                        manifest: manifest,
                        showWalletPicker: true,
                        isSilentConnect: false
                    )

                    coordinator.didCancel = { [weak self, weak coordinator] in
                        guard let coordinator else { return }
                        self?.removeChild(coordinator)
                    }

                    coordinator.didConnect = { [weak self, weak coordinator] in
                        guard let coordinator else { return }
                        self?.removeChild(coordinator)
                    }

                    coordinator.didRequestOpeningBrowser = { [weak self] manifest in
                        self?.openDapp(title: manifest.name, url: manifest.url, analyticsFrom: .tonconnect)
                    }

                    addChild(coordinator)
                    coordinator.start()
                }
            case let .failure(error):
                ToastPresenter.hideToast()
                ToastPresenter.showToast(
                    configuration: ToastPresenter.Configuration(
                        title: error.description
                    )
                )
            }
        }
        return true
    }

    func handleSignerDeeplink(_ deeplink: ExternalSignDeeplink) -> Bool {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()

        switch deeplink {
        case let .link(publicKey, name):
            let coordinator = AddWalletModule(
                dependencies: AddWalletModule.Dependencies(
                    walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                    storesAssembly: keeperCoreMainAssembly.storesAssembly,
                    coreAssembly: coreAssembly,
                    keeperCoreMainAssembly: keeperCoreMainAssembly,
                    multichainAssembly: keeperCoreMainAssembly.multichainAssembly,
                    scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                    configurationAssembly: keeperCoreMainAssembly.configurationAssembly
                )
            ).createPairSignerDeeplinkCoordinator(
                publicKey: publicKey,
                name: name,
                router: NavigationControllerRouter(
                    rootViewController: navigationController
                ),
                analyticsContext: WalletFlowAnalyticsContext(from: .main)
            )

            coordinator.didPrepareToPresent = { [weak self, weak navigationController] in
                guard let navigationController else { return }
                if self?.router.rootViewController.presentedViewController != nil {
                    self?.router.dismiss(animated: true, completion: {
                        self?.router.present(navigationController)
                    })
                } else {
                    self?.router.present(navigationController)
                }
            }

            coordinator.didPaired = { [weak self, weak coordinator, weak navigationController] in
                navigationController?.dismiss(animated: true)
                self?.removeChild(coordinator)
            }

            coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
                navigationController?.dismiss(animated: true)
                self?.removeChild(coordinator)
            }

            addChild(coordinator)
            coordinator.start()
        }
        return true
    }

    private weak var presentedWalletPicker: TKBottomSheetViewController?

    func openWalletPicker() {
        guard presentedWalletPicker == nil else { return }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let module = WalletsListAssembly.module(
            model: WalletsPickerListModel(
                walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore
            ),
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            raffleStore: keeperCoreMainAssembly.storesAssembly.raffleStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            tooltipsService: coreAssembly.tooltipsAssembly.service,
            shouldShowAddMultichainWalletTooltip: shouldShowAddMultichainWalletTooltip
        )

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
        presentedWalletPicker = bottomSheetViewController

        var didOpenAddWallet = false
        module.output.addButtonEvent = { [weak self, unowned bottomSheetViewController] in
            guard !didOpenAddWallet else { return }
            didOpenAddWallet = true
            bottomSheetViewController.dismiss {
                guard let self else { return }
                self.openAddWallet(router: ViewControllerRouter(rootViewController: self.router.rootViewController))
            }
        }

        module.output.didTapEditWallet = { [weak self, unowned bottomSheetViewController] wallet in
            self?.openEditWallet(wallet: wallet, fromViewController: bottomSheetViewController)
        }

        module.output.didSelectWallet = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        module.output.onOpenRaffle = { [weak self, unowned bottomSheetViewController] in
            bottomSheetViewController.dismiss {
                self?.openMysteryRaffle(source: .walletsList)
            }
        }

        module.output.onOpenRaffleBanner = { [weak self, unowned bottomSheetViewController] url in
            bottomSheetViewController.dismiss {
                self?.openURL(url, title: nil)
            }
        }

        bottomSheetViewController.present(fromViewController: router.rootViewController)
    }

    func openMysteryRaffle(source: RaffleSource) {
        MysteryRaffleCoordinator.presentCurrent(
            from: self,
            rootViewController: router.rootViewController,
            source: source,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            presentedFromBanner: source == .walletsList,
            openDeeplink: { [weak self] in self?.handleRaffleDeeplink($0) },
            openMigration: { [weak self] onFinish in
                self?.openMigrationDeeplink(source: .raffle, onFinish: onFinish)
            }
        )
    }

    /// Auto-shows the raffle's story after launch. `RaffleStore` is empty until the
    /// wallet-scoped fetch answers (and stays empty for wallets without a multichain id),
    /// so the trigger is the store emission rather than `start()` itself.
    private func setupRaffleLaunchStory() {
        let raffleStore = keeperCoreMainAssembly.storesAssembly.raffleStore
        presentRaffleLaunchStoryIfNeeded(raffles: raffleStore.getState())
        raffleStore.addObserver(self) { coordinator, event in
            guard case let .didUpdateRaffles(raffles) = event else { return }
            Task { @MainActor in
                coordinator.presentRaffleLaunchStoryIfNeeded(raffles: raffles)
            }
        }
    }

    private func presentRaffleLaunchStoryIfNeeded(raffles: [MultichainRaffle]) {
        guard !didPresentRaffleLaunchStory,
              !isBootConfigurationStoriesRunning,
              !areLaunchStoriesSuppressed
        else { return }
        didPresentRaffleLaunchStory = MysteryRaffleCoordinator.presentLaunchStory(
            raffles: raffles,
            rootViewController: router.rootViewController,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            openDeeplink: { [weak self] in self?.handleRaffleDeeplink($0) }
        )
    }

    /// The wallet the tab bar itself is standing on, for the requests it makes on nobody's behalf.
    var activeWalletScopeId: String? {
        (try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet)?
            .multichainWalletState?
            .walletId
    }

    /// Plays the boot configuration's stories once per launch. The two auto-open paths own
    /// separate presenter windows, so the raffle's launch story is held back while these run —
    /// a raffle emission landing mid-sequence would otherwise stack a second story window over
    /// the visible one. Only the presentation waits: the `raffleStore` observer is registered
    /// either way, so nothing is lost if this never finishes.
    private func runBootConfigurationStories() {
        guard !areLaunchStoriesSuppressed else { return }
        isBootConfigurationStoriesRunning = true
        guard let storiesController = mainCoordinatorStoriesController else {
            finishBootConfigurationStories(didComplete: true)
            return
        }
        storiesController.runBootConfigurationStories(
            walletId: activeWalletScopeId,
            // Claimed as each story goes on screen — a turn before `StoriesService` gets to
            // record it — so the raffle's own auto-open can't pick the same story up in
            // between, and stays covered if that record fails to persist.
            didPresentStory: { [weak self] storyID in
                guard let self else { return }
                MysteryRaffleStoriesRouter
                    .make(keeperCoreMainAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)
                    .excludeAutoOpenStoryIDs([storyID])
            },
            completion: { [weak self] didComplete in
                self?.finishBootConfigurationStories(didComplete: didComplete)
            }
        )
    }

    /// Something else took over the launch — a deeplink, a push tap. The remaining boot stories
    /// must not open on top of wherever the user is being taken, and the hold on the raffle's
    /// launch story is released right away rather than waiting for a dismissal that the user
    /// may never give.
    private func cancelBootConfigurationStories() {
        mainCoordinatorStoriesController?.cancelBootConfigurationStories()
        finishBootConfigurationStories(didComplete: false)
    }

    /// Releases the hold the boot stories put on the raffle's launch story. `didComplete` is
    /// false when the run ended early — a page button routed the user somewhere, or a deeplink
    /// took over — so the launch story must not land on top of that, and only the `raffleStore`
    /// observer is left to pick it up.
    private func finishBootConfigurationStories(didComplete: Bool) {
        guard isBootConfigurationStoriesRunning else { return }
        isBootConfigurationStoriesRunning = false
        guard didComplete else {
            areLaunchStoriesSuppressed = true
            return
        }
        presentRaffleLaunchStoryIfNeeded(raffles: keeperCoreMainAssembly.storesAssembly.raffleStore.getState())
    }

    /// Generic deeplink dispatch handed to every raffle surface (CTAs, earn tasks, story
    /// buttons) so backend-driven payloads route like any other in-app deeplink.
    func handleRaffleDeeplink(_ deeplink: String) {
        _ = handleDeeplink(deeplink: deeplink, fromStories: false)
    }

    func openAddWallet(router: ViewControllerRouter) {
        // A second run would drop the coordinator this one is holding, and the dropped flow's
        // own completion would then clear the reference to its replacement.
        guard addWalletCoordinator == nil else { return }
        let module = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                multichainAssembly: keeperCoreMainAssembly.multichainAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        )

        let coordinator = module.createAddWalletCoordinator(
            options: [
                .createMultichain,
                .importRegular,
                .signer,
                .keystone,
                .ledger,
                .importWatchOnly,
            ],
            router: router,
            analyticsContext: module.makeWalletFlowAnalyticsContext(from: .main)
        )
        coordinator.didAddWallets = { [weak self, weak coordinator] in
            guard let self else { return }
            self.addWalletCoordinator = nil
            if let coordinator {
                self.removeChild(coordinator)
            }
            ToastPresenter.showNoInternetConnectionToastIfNeeded { [weak self] in
                self?.reachabilityTracker.state == .noInternetConnection
            }
        }
        coordinator.didCancel = { [weak self, weak coordinator] in
            self?.addWalletCoordinator = nil
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        addWalletCoordinator = coordinator

        addChild(coordinator)
        coordinator.start()
    }

    /// Testnet import lives in the dev menu only: the add-wallet picker offered it to everyone,
    /// and users kept importing their seed phrase there and mistaking the testnet address for their own.
    func openImportTestnetWallet() {
        guard importTestnetWalletCoordinator == nil else { return }

        let module = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                multichainAssembly: keeperCoreMainAssembly.multichainAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        )

        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()

        let coordinator = module.createImportWalletCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            network: .testnet,
            analyticsContext: module.makeWalletFlowAnalyticsContext(from: .main)
        )

        var isFlowFinished = false
        weak var presentationDelegate: ModalPresentationDelegate?
        let finishFlow: () -> Void = { [weak self, weak coordinator] in
            guard !isFlowFinished else { return }
            isFlowFinished = true
            self?.importTestnetWalletCoordinator = nil
            self?.clearModalPresentationDelegate(presentationDelegate)
            self?.removeChild(coordinator)
        }

        let finish: () -> Void = { [weak navigationController] in
            navigationController?.dismiss(animated: true)
            finishFlow()
        }
        coordinator.didCancel = finish
        coordinator.didImportWallets = finish

        importTestnetWalletCoordinator = coordinator

        addChild(coordinator)
        coordinator.start()

        presentationDelegate = presentModally(
            navigationController,
            from: router.rootViewController,
            onDismiss: finishFlow
        )
    }

    func openEditWallet(wallet: Wallet, fromViewController: UIViewController) {
        let addWalletModuleModule = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                multichainAssembly: keeperCoreMainAssembly.multichainAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        )

        let module = addWalletModuleModule.createCustomizeWalletModule(
            name: wallet.label,
            tintColor: wallet.tintColor,
            icon: wallet.metaData.icon,
            configurator: EditWalletCustomizeWalletViewModelConfigurator()
        )

        module.output.didCustomizeWallet = { [weak self] model in
            guard let self else { return }
            let walletsStore = self.keeperCoreMainAssembly.storesAssembly.walletsStore
            Task {
                await walletsStore.updateWalletMetaData(
                    wallet,
                    metaData: WalletMetaData(customizeWalletModel: model)
                )
            }
        }

        let navigationController = TKNavigationController(rootViewController: module.view)

        module.view.setupHeaderRightCloseButton { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        }

        fromViewController.present(navigationController, animated: true)
    }

    func openSupport() {
        let directSupportURL = keeperCoreMainAssembly.configurationAssembly.configuration.directSupportUrl
        let supportEmailURL = keeperCoreMainAssembly.configurationAssembly.configuration.supportLink
        let urlOpener = coreAssembly.urlOpener()

        SupportPopupPresenter.present(
            directSupportURL: directSupportURL,
            supportEmailURL: supportEmailURL,
            from: router.rootViewController.topPresentedViewController(),
            onOpenURL: { urlOpener.open(url: $0) }
        )
    }

    func openSettings(wallet: Wallet) {
        guard let navigationController = router.rootViewController.navigationController else { return }
        let module = SettingsModule(
            dependencies: SettingsModule.Dependencies(
                inAppReviewService: inAppReviewService,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly,
                depositPendingTracker: depositPendingTracker
            )
        )

        let router = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = module.createSettingsCoordinator(
            router: router,
            wallet: wallet
        )

        coordinator.didTapBattery = { [weak self] wallet in
            self?.openBattery(
                wallet: wallet,
                initiatedBy: .user
            )
        }

        coordinator.didTapSupport = { [weak self] in
            self?.openSupport()
        }

        coordinator.didRequestOpenMerchantURL = { [weak self] url, fromViewController in
            self?.openBuySellItemURL(url, fromViewController: fromViewController)
        }

        coordinator.didRequestImportTestnetWallet = { [weak self] in
            self?.openImportTestnetWallet()
        }

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openTonDetails(
        wallet: Wallet,
        analyticsSource: AssetViewAnalyticsSource = .walletScreen,
        navigationControllerOrNil: UINavigationController? = nil
    ) {
        let navigationController = navigationControllerOrNil ?? router.rootViewController.navigationController
        guard let navigationController else {
            return
        }
        if wallet.network.isMainnet,
           let tradeCoordinator
        {
            tradeCoordinator.openAssetDetails(
                preview: AssetIdResolver
                    .tonPreviewContext(
                        wallet: wallet
                    ),
                on: navigationController,
                source: analyticsSource
            )
            return
        }
        let historyListModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createTonHistoryListModule(wallet: wallet)

        historyListModule.output.didSelectEvent = { [weak self] event in
            switch event {
            case let .tonEvent(event):
                self?.openHistoryEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            case let .tronEvent(event):
                self?.openTronEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            }
        }

        let module = TokenDetailsAssembly.module(
            wallet: wallet,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            configurator: makeTokenDetailsConfigurator(
                wallet: wallet,
                token: .ton(.ton)
            ),
            tokenDetailsListContentViewController: historyListModule.view,
            chartViewControllerProvider: { [keeperCoreMainAssembly, coreAssembly] in
                ChartAssembly.module(
                    token: .ton(.ton),
                    wallet: wallet,
                    coreAssembly: coreAssembly,
                    keeperCoreMainAssembly: keeperCoreMainAssembly
                ).view
            },
            shouldReserveChartSpace: true
        )

        module.output.didTapReceive = { [weak self] token in
            self?.openReceive(token: token, wallet: wallet)
        }

        module.output.didTapSend = { [weak self] token in
            self?.openSendResolvingMultichain(
                wallet: wallet,
                sendInput: .direct(item: token.sendV3Item),
                sendSource: .jettonScreen,
                comment: nil
            )
        }

        module.output.didTapSwap = { [weak self] token in
            self?.openSwap(wallet: wallet, token: token)
        }

        module.output.didOpenURL = { [weak self] url in
            self?.openURL(url, title: nil)
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openJettonDetails(
        jettonItem: JettonItem,
        wallet: Wallet,
        hasPrice: Bool,
        analyticsSource: AssetViewAnalyticsSource = .walletScreen,
        navigationControllerOrNil: UINavigationController? = nil
    ) {
        let navigationController = navigationControllerOrNil ?? router.rootViewController.navigationController
        guard let navigationController else {
            return
        }
        if wallet.network.isMainnet,
           let tradeCoordinator
        {
            tradeCoordinator.openAssetDetails(
                preview: AssetIdResolver
                    .jettonPreviewContext(
                        wallet: wallet,
                        jettonItem: jettonItem
                    ),
                on: navigationController,
                source: analyticsSource
            )
            return
        }

        let historyListModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createJettonHistoryListModule(jettonMasterAddress: jettonItem.jettonInfo.address, wallet: wallet)

        historyListModule.output.didSelectEvent = { [weak self] event in
            switch event {
            case let .tonEvent(event):
                self?.openHistoryEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            case let .tronEvent(event):
                self?.openTronEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            }
        }

        let module = TokenDetailsAssembly.module(
            wallet: wallet,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            configurator: makeTokenDetailsConfigurator(
                wallet: wallet,
                token: .ton(.jetton(jettonItem))
            ),
            tokenDetailsListContentViewController: historyListModule.view,
            chartViewControllerProvider: { [keeperCoreMainAssembly, coreAssembly] in
                guard hasPrice else { return nil }
                return ChartAssembly.module(
                    token: .ton(.jetton(jettonItem)),
                    wallet: wallet,
                    coreAssembly: coreAssembly,
                    keeperCoreMainAssembly: keeperCoreMainAssembly
                ).view
            },
            shouldReserveChartSpace: hasPrice
        )

        module.output.didTapReceive = { [weak self] token in
            self?.openReceive(token: token, wallet: wallet)
        }

        module.output.didTapSend = { [weak self] token in
            self?.openSendResolvingMultichain(
                wallet: wallet,
                sendInput: .direct(item: token.sendV3Item),
                sendSource: .jettonScreen,
                comment: nil
            )
        }

        module.output.didTapSwap = { [weak self] token in
            self?.openSwap(wallet: wallet, token: token)
        }

        module.output.didOpenURL = { [weak self] url in
            self?.openURL(url, title: nil)
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openTronUSDTDetails(
        wallet: Wallet,
        analyticsSource: AssetViewAnalyticsSource = .walletScreen,
        navigationControllerOrNil: UINavigationController? = nil
    ) {
        let navigationController = navigationControllerOrNil ?? router.rootViewController.navigationController
        guard let navigationController else {
            return
        }
        Task {
            await keeperCoreMainAssembly.servicesAssembly.tronUSDTFeesService.refresh(wallet: wallet)
        }
        if wallet.network.isMainnet,
           let tradeCoordinator,
           let walletTron = wallet.tron
        {
            tradeCoordinator.openAssetDetails(
                preview: AssetIdResolver
                    .usdtTrc20PreviewContext(
                        wallet: wallet,
                        walletTron: walletTron
                    ),
                on: navigationController,
                source: analyticsSource
            )
            return
        }

        let historyListModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createTronUSDTHistoryListModule(wallet: wallet)

        historyListModule.output.didSelectEvent = { [weak self] event in
            switch event {
            case let .tonEvent(event):
                self?.openHistoryEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            case let .tronEvent(event):
                self?.openTronEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            }
        }

        let configuration = makeTronDetailsConfigurator(wallet: wallet)

        let module = TokenDetailsAssembly.module(
            wallet: wallet,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            configurator: configuration,
            tokenDetailsListContentViewController: historyListModule.view,
            chartViewControllerProvider: { [keeperCoreMainAssembly, coreAssembly] in
                ChartAssembly.module(
                    token: .tron(.usdt),
                    wallet: wallet,
                    coreAssembly: coreAssembly,
                    keeperCoreMainAssembly: keeperCoreMainAssembly
                ).view
            },
            shouldReserveChartSpace: true
        )

        module.output.didTapReceive = { [weak self] token in
            self?.openReceive(token: token, wallet: wallet)
        }

        module.output.didTapSend = { [weak self, weak configuration] token in
            guard let self, let configuration else {
                return
            }
            let tronUSDTFeesService = keeperCoreMainAssembly.servicesAssembly.tronUSDTFeesService
            let feesSnapshot = keeperCoreMainAssembly.storesAssembly
                .processedBalanceStore
                .getState()[wallet]
                .flatMap { state in
                    tronUSDTFeesService.snapshot(wallet: wallet, balance: state.balance)
                }
            if let feesSnapshot, !feesSnapshot.hasEnoughForAtLeastOneTransfer {
                if feesSnapshot.isTRXOnlyRegion {
                    return openInsufficientFundsPopup(
                        configuration: configuration.insufficientTrxSheetConfiguration(
                            for: feesSnapshot,
                            onGetTrx: { [weak self] in
                                guard let self else {
                                    return
                                }
                                router.dismiss { [weak self] in
                                    self?.openReceive(token: .tron(.trx), wallet: wallet)
                                }
                            }
                        )
                    )
                } else {
                    return openUsdtFees(wallet: wallet, snapshot: feesSnapshot, reason: .insufficient)
                }
            }

            openSendResolvingMultichain(
                wallet: wallet,
                sendInput: .direct(item: token.sendV3Item),
                sendSource: .jettonScreen,
                comment: nil
            )
        }

        module.output.didTapSwap = { [weak self] token in
            self?.openSwap(wallet: wallet, token: token)
        }

        module.output.didOpenURL = { [weak self] url in
            self?.openURL(url, title: nil)
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openTronTRXDetails(
        wallet: Wallet,
        analyticsSource: AssetViewAnalyticsSource = .walletScreen,
        navigationControllerOrNil: UINavigationController? = nil
    ) {
        let navigationController = navigationControllerOrNil ?? router.rootViewController.navigationController
        guard let navigationController else {
            return
        }
        if wallet.network.isMainnet,
           let tradeCoordinator,
           let walletTron = wallet.tron
        {
            tradeCoordinator.openAssetDetails(
                preview: AssetIdResolver
                    .trxPreviewContext(
                        wallet: wallet,
                        walletTron: walletTron
                    ),
                on: navigationController,
                source: analyticsSource
            )
            return
        }

        let historyListModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createTronTRXHistoryListModule(wallet: wallet)

        historyListModule.output.didSelectEvent = { [weak self] event in
            switch event {
            case let .tonEvent(event):
                self?.openHistoryEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            case let .tronEvent(event):
                self?.openTronEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            }
        }

        let module = TokenDetailsAssembly.module(
            wallet: wallet,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            configurator: TronTRXTokenDetailsConfigurator(
                wallet: wallet,
                mapper: TokenDetailsMapper(
                    amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                    rateConverter: RateConverter()
                )
            ),
            tokenDetailsListContentViewController: historyListModule.view,
            chartViewControllerProvider: { [keeperCoreMainAssembly, coreAssembly] in
                ChartAssembly.module(
                    token: .tron(.trx),
                    wallet: wallet,
                    coreAssembly: coreAssembly,
                    keeperCoreMainAssembly: keeperCoreMainAssembly
                ).view
            },
            shouldReserveChartSpace: true
        )

        module.output.didTapReceive = { [weak self] token in
            self?.openReceive(token: token, wallet: wallet)
        }

        module.output.didTapSend = { [weak self] token in
            self?.openSendResolvingMultichain(
                wallet: wallet,
                sendInput: .direct(item: token.sendV3Item),
                sendSource: .jettonScreen,
                comment: nil
            )
        }

        module.output.didOpenURL = { [weak self] url in
            self?.openURL(url, title: nil)
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func handleTronUsdtFees(
        wallet: Wallet,
        snapshot: TronUsdtFeesSnapshot,
        trigger: TradeAssetDetailsTronFeesTrigger
    ) {
        switch trigger {
        case .transfersAvailable:
            openUsdtFees(wallet: wallet, snapshot: snapshot, reason: .topup)
        case .banner:
            if snapshot.isTRXOnlyRegion {
                openReceive(token: .tron(.trx), wallet: wallet)
            } else {
                openUsdtFees(wallet: wallet, snapshot: snapshot, reason: .topup)
            }
        case .insufficientSend:
            if snapshot.isTRXOnlyRegion {
                openInsufficientFundsPopup(
                    configuration: TronUsdtInsufficientTrxSheet.configuration(
                        for: snapshot,
                        amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                        onGetTrx: { [weak self] in
                            guard let self else {
                                return
                            }
                            router.dismiss { [weak self] in
                                self?.openReceive(token: .tron(.trx), wallet: wallet)
                            }
                        }
                    )
                )
            } else {
                openUsdtFees(wallet: wallet, snapshot: snapshot, reason: .insufficient)
            }
        }
    }

    func openUsdtFees(wallet: Wallet, snapshot: TronUsdtFeesSnapshot, reason: TopUpReason) {
        guard let navigationController = router.rootViewController.navigationController else { return }

        let coordinator = TopUpCoordinator(
            wallet: wallet,
            reason: reason,
            snapshot: snapshot,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )
        coordinator.openBattery = { [weak self] in
            self?.openBattery(wallet: wallet, keepCurrentModal: true, initiatedBy: .user)
        }
        self.topUpCoordinator = coordinator

        addChild(coordinator)
        coordinator.start()
    }

    func openEthenaDetails(wallet: Wallet) {
        guard let navigationController = router.rootViewController.navigationController else { return }

        let historyListModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createJettonHistoryListModule(jettonMasterAddress: JettonMasterAddress.USDe, wallet: wallet)

        historyListModule.output.didSelectEvent = { [weak self] event in
            switch event {
            case let .tonEvent(event):
                self?.openHistoryEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            case let .tronEvent(event):
                self?.openTronEventDetails(wallet: wallet, event: event, network: wallet.network, fromViewController: nil)
            }
        }

        let configurator = EthenaDetailsConfigurator(
            wallet: wallet,
            mapper: TokenDetailsMapper(
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                rateConverter: RateConverter()
            ),
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            ethenaStakingLoader: keeperCoreMainAssembly.loadersAssembly.ethenaStakingLoader(wallet: wallet),
            balanceItemMapper: BalanceItemMapper(
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
            ),
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        configurator.didSelectJetton = { [weak self] jetton in
            self?.openJettonDetails(jettonItem: jetton, wallet: wallet, hasPrice: false)
        }

        configurator.didSelectStakingEthena = { [weak self] in
            self?.openEthenaStakingDetails(wallet: wallet)
        }

        configurator.didOpenURL = { [weak self] url in
            self?.openInAppURL(url: url)
        }

        configurator.didOpenDapp = { [weak self] url, title in
            self?.openDapp(title: title, url: url, analyticsFrom: .deepLink, isSilentConnect: true)
        }

        let module = TokenDetailsAssembly.module(
            wallet: wallet,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            configurator: configurator,
            tokenDetailsListContentViewController: historyListModule.view,
            chartViewControllerProvider: nil
        )

        module.output.didTapReceive = { [weak self] token in
            self?.openReceive(token: token, wallet: wallet)
        }

        module.output.didTapSend = { [weak self] token in
            self?.openSendResolvingMultichain(
                wallet: wallet,
                sendInput: .direct(item: token.sendV3Item),
                sendSource: .jettonScreen,
                comment: nil
            )
        }

        module.output.didTapSwap = { [weak self] token in
            self?.openSwap(wallet: wallet, token: token)
        }

        module.output.didOpenURL = { [weak self] url in
            self?.openURL(url, title: nil)
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openEthenaStakingDetails(wallet: Wallet) {
        guard let navigationController = router.rootViewController.navigationController else { return }

        let module = EthenaStakingDetailsAssembly.module(
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        module.output.didOpenURL = { [weak self] in
            self?.coreAssembly.urlOpener().open(url: $0)
        }

        module.output.didOpenURLInApp = { [weak self] url in
            self?.openInAppURL(url: url)
        }

        module.output.didOpenDapp = { [weak self] url, title in
            self?.openDapp(title: title, url: url, analyticsFrom: .deepLink)
        }

        module.output.openJettonDetails = { [weak self] wallet, jettonItem in
            self?.openJettonDetails(jettonItem: jettonItem, wallet: wallet, hasPrice: true)
        }

        module.output.didTapStake = { [weak self] wallet, stakingPoolInfo in
            self?.openStake(wallet: wallet, stakingPoolInfo: stakingPoolInfo, initiatedBy: .user)
        }

        module.output.didTapUnstake = { [weak self] wallet, stakingPoolInfo in
            self?.openUnstake(wallet: wallet, stakingPoolInfo: stakingPoolInfo, initiatedBy: .user)
        }

        module.output.didTapCollect = { [weak self] in
            self?.openStakingCollect(
                wallet: $0,
                stakingPoolInfo: $1,
                accountStackingInfo: $2,
                initiatedBy: .user
            )
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openStakingItemDetails(
        wallet: Wallet,
        stakingPoolInfo: StackingPoolInfo,
        initiatedBy: InitiatedBy,
        utm: UtmParameters = .empty
    ) {
        guard let navigationController = router.rootViewController.navigationController else { return }

        let module = StakingBalanceDetailsAssembly.module(
            wallet: wallet,
            stakingPoolInfo: stakingPoolInfo,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        module.output.didOpenURL = { [weak self] in
            self?.coreAssembly.urlOpener().open(url: $0)
        }

        module.output.didOpenURLInApp = { [weak self] url, title in
            self?.openURL(url, title: title)
        }

        module.output.openJettonDetails = { [weak self] wallet, jettonItem in
            self?.openJettonDetails(jettonItem: jettonItem, wallet: wallet, hasPrice: true)
        }

        module.output.didTapStake = { [weak self] wallet, stakingPoolInfo in
            self?.openStake(
                wallet: wallet,
                stakingPoolInfo: stakingPoolInfo,
                initiatedBy: initiatedBy,
                utm: utm
            )
        }

        module.output.didTapUnstake = { [weak self] wallet, stakingPoolInfo in
            self?.openUnstake(
                wallet: wallet,
                stakingPoolInfo: stakingPoolInfo,
                initiatedBy: initiatedBy,
                utm: utm
            )
        }

        module.output.didTapCollect = { [weak self] in
            self?.openStakingCollect(
                wallet: $0,
                stakingPoolInfo: $1,
                accountStackingInfo: $2,
                initiatedBy: initiatedBy,
                utm: utm
            )
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openStakingCollect(
        wallet: Wallet,
        stakingPoolInfo: StackingPoolInfo,
        accountStackingInfo: AccountStackingInfo,
        initiatedBy: InitiatedBy,
        utm: UtmParameters = .empty
    ) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = StakingConfirmationCoordinator(
            wallet: wallet,
            item: StakingConfirmationItem(
                operation: .withdraw(stakingPoolInfo, isCollect: true),
                amount: BigUInt(accountStackingInfo.readyWithdraw)
            ),
            initiatedBy: initiatedBy,
            utm: utm,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
            navigationController?.dismiss(animated: true)
            self?.removeChild(coordinator)
        }

        self.stakingConfirmationCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: nil)

        router.present(navigationController)
    }

    func openURL(_ url: URL, title: String?) {
        if let deeplink = try? keeperCoreMainAssembly.deeplinkParser.parse(
            string: url.absoluteString,
            source: .browser
        ), handleDeeplink(
            deeplink: deeplink,
            fromStories: false,
            utm: UtmParameters(link: url.absoluteString)
        ) {
            return
        }
        router.rootViewController.modalPresentationSourceViewController().present(
            bridgeViewController(for: url, title: title),
            animated: true
        )
    }

    private func bridgeViewController(for url: URL, title: String?) -> TKBridgeWebViewController {
        TKBridgeWebViewController(
            initialURL: url,
            initialTitle: nil,
            jsInjection: nil,
            configuration: .default,
            deeplinkHandler: { [weak self] url in
                guard let self else { return }
                do {
                    let deeplink = try keeperCoreMainAssembly.deeplinkParser.parse(
                        string: url,
                        source: .browser
                    )
                    _ = self.handleDeeplink(
                        deeplink: deeplink,
                        fromStories: false,
                        utm: UtmParameters(link: url)
                    )
                } catch let error as DeeplinkParserError where error.isSilent {
                    return
                } catch {
                    throw error
                }
            }
        )
    }

    func openInAppURL(url: URL) {
        let viewController = SFSafariViewController(url: url)
        router.present(viewController)
    }

    func openBuySellItemURL(_ url: URL, fromViewController: UIViewController) {
        let deeplinkHandler = TKWebViewControllerNavigationHandler(
            deeplinkParser: keeperCoreMainAssembly.deeplinkParser,
            openDeeplinkHandler: { [weak self] deeplink, utm in
                _ = self?.handleDeeplink(
                    deeplink: deeplink,
                    fromStories: false,
                    utm: utm
                )
            }
        )

        let webViewController = TKWebViewController(url: url, handler: deeplinkHandler)
        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.modalPresentationStyle = .fullScreen
        navigationController.configureTransparentAppearance()
        fromViewController.present(navigationController, animated: true)
    }

    func openStake(wallet: Wallet, stakingPoolInfo: StackingPoolInfo, initiatedBy: InitiatedBy, utm: UtmParameters = .empty) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = StakingStakeCoordinator(
            wallet: wallet,
            stakingPoolInfo: stakingPoolInfo,
            initiatedBy: initiatedBy,
            utm: utm,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )

        coordinator.didFinish = { [weak self] in
            self?.router.dismiss()
            self?.removeChild($0)
        }

        coordinator.didClose = { [weak self, weak coordinator] in
            self?.router.dismiss()
            self?.removeChild(coordinator)
        }

        self.stakingStakeCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: nil)

        self.router.dismiss(animated: true) { [weak self, weak coordinator] in
            self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
            })
        }
    }

    func openUnstake(wallet: Wallet, stakingPoolInfo: StackingPoolInfo, initiatedBy: InitiatedBy, utm: UtmParameters = .empty) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = StakingUnstakeCoordinator(
            wallet: wallet,
            stakingPoolInfo: stakingPoolInfo,
            initiatedBy: initiatedBy,
            utm: utm,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )

        coordinator.didFinish = { [weak self] in
            self?.router.dismiss()
            self?.removeChild($0)
        }

        coordinator.didClose = { [weak self, weak coordinator] in
            self?.router.dismiss()
            self?.removeChild(coordinator)
        }

        self.stakingUnstakeCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: nil)

        self.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
        })
    }

    func openRamp(
        flow: RampFlow,
        wallet: Wallet,
        initialDeeplink: RampDeeplinkParameters? = nil,
        entrySource: DepositAnalyticsSource,
        utm: UtmParameters = .empty,
        presentingViewController: UIViewController? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
        let rampRouter = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = RampCoordinator(
            flow: flow,
            router: rampRouter,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            initialDeeplink: initialDeeplink,
            entrySource: entrySource,
            utm: utm,
            depositPendingTracker: depositPendingTracker
        )

        coordinator.didTapReceive = { [weak self] wallet in
            guard let self else { return }
            openReceive(
                tokens: getRampTokens(wallet: wallet),
                wallet: wallet,
                onDidDisplayToken: { [weak self] token in
                    guard let self, flow == .deposit else { return }
                    self.coreAssembly.analyticsProvider.log(
                        entrySource.makeDepositViewReceiveTokens(token: token),
                        utm: utm
                    )
                }
            )
        }

        coordinator.didTapSend = { [weak self] wallet, token in
            self?.openSendResolvingMultichain(
                wallet: wallet,
                sendInput: .direct(item: .ton(.token(token, amount: 0))),
                sendSource: .walletScreen,
                comment: nil
            )
        }

        coordinator.didTapOpenSendFromWithdraw = { [weak self] wallet, sendInput in
            guard let self else { return }
            self.openSendPushedOnto(
                wallet: wallet,
                sendInput: sendInput,
                sendSource: sendAnalyticsSource(for: entrySource, utm: utm),
                comment: nil,
                pushRouter: rampRouter
            )
        }

        coordinator.didTapOpenMerchant = { [weak self, weak navigationController] url in
            guard let self, let navigationController else { return }
            self.openBuySellItemURL(url, fromViewController: navigationController)
        }

        var isFlowFinished = false
        weak var presentationDelegate: ModalPresentationDelegate?
        let finishFlow: () -> Void = { [weak self, weak coordinator] in
            guard !isFlowFinished else { return }
            isFlowFinished = true
            self?.clearModalPresentationDelegate(presentationDelegate)
            self?.removeChild(coordinator)
            onDismiss?()
        }

        let isCustomPresentation = presentingViewController != nil
        coordinator.didClose = { [weak self, weak navigationController] in
            if isCustomPresentation {
                navigationController?.dismiss(animated: true)
            } else {
                self?.router.dismiss()
            }
            finishFlow()
        }

        addChild(coordinator)
        coordinator.start()

        if let presentingViewController {
            presentationDelegate = presentModally(
                navigationController,
                from: presentingViewController,
                onDismiss: finishFlow
            )
        } else {
            router.dismiss(animated: true) { [weak self] in
                self?.router.present(navigationController, onDismiss: finishFlow)
            }
        }
    }

    func openMultichainOfframpFromAsset(
        wallet: Wallet,
        assetId: String,
        resolvedAsset: MultichainAsset? = nil,
        presentingViewController: UIViewController?
    ) async {
        guard case let .multichain(multichainState) = wallet.multichain else {
            return
        }

        if let resolvedAsset {
            openMultichainRamp(
                mode: .withdraw(resolvedAsset),
                wallet: wallet,
                presentingViewController: presentingViewController
            )
            return
        }

        let assetResolver = MultichainSendAssetResolver(
            multichainAssetBalanceProvider: keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider,
            assetDetailsService: keeperCoreMainAssembly.servicesAssembly.assetDetailsService()
        )
        guard let asset = await assetResolver.resolveAsset(for: assetId, multichainState: multichainState) else {
            ToastPresenter.showToast(
                configuration: ToastPresenter.Configuration(
                    title: TKLocales.Trade.Assets.Errors.load
                )
            )
            return
        }

        openMultichainRamp(
            mode: .withdraw(asset),
            wallet: wallet,
            presentingViewController: presentingViewController
        )
    }

    /// A fee the wallet is short of is topped up through the ramp with the asset already chosen.
    /// Whatever keeps the ramp shut — no multichain addresses, an asset the resolver cannot load —
    /// falls back to the receive screen: the user is short of gas either way and still needs a way
    /// to deposit.
    func openFeeRefill(
        token: Token,
        wallet: Wallet,
        onRefill: @escaping () -> Void
    ) {
        Task {
            await self.openMultichainOnrampFromAsset(
                wallet: wallet,
                assetId: token.assetId(network: wallet.network),
                presentingViewController: self.router.rootViewController.topPresentedViewController(),
                onDismiss: onRefill,
                onUnavailable: {
                    self.openReceive(token: token, wallet: wallet, onClose: onRefill)
                }
            )
        }
    }

    /// The receive screen for the chain a fee asset lives on: all a deposit needs is the wallet's
    /// address there, which stays reachable even when the ramp cannot resolve the asset itself.
    func openReceiveForFeeAsset(
        assetId: String,
        wallet: Wallet,
        onClose: @escaping () -> Void
    ) {
        guard case let .multichain(multichainState) = wallet.multichain,
              let chain = MultichainChain(assetId: assetId),
              let address = multichainState.walletAddress(
                  for: chain,
                  preferredType: wallet.preferredMultichainAddressType(for: chain)
              )
        else {
            // Nothing was presented, so the caller has to hear about it: it is waiting on this to
            // re-price the fee. The ramp swallowed its own error toast on the way here, having been
            // told this fallback would take over, so the only report left to make is this one.
            Log.w("fee deposit skipped - no receive address for \(assetId)")
            ToastPresenter.showToast(
                configuration: ToastPresenter.Configuration(
                    title: TKLocales.Trade.Assets.Errors.load
                )
            )
            onClose()
            return
        }
        openReceive(
            wallet: wallet,
            address: ReceiveAddressPreview(address: address),
            onClose: onClose
        )
    }

    /// A caller with its own way to take a deposit passes `onUnavailable` and gets it instead of the
    /// error toast, which is a dead end for anyone who opened the ramp to cover a fee.
    func openMultichainOnrampFromAsset(
        wallet: Wallet,
        assetId: String,
        presentingViewController: UIViewController?,
        onDismiss: (() -> Void)? = nil,
        onUnavailable: (() -> Void)? = nil
    ) async {
        guard case let .multichain(multichainState) = wallet.multichain else {
            onUnavailable?()
            return
        }

        let assetResolver = MultichainSendAssetResolver(
            multichainAssetBalanceProvider: keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider,
            assetDetailsService: keeperCoreMainAssembly.servicesAssembly.assetDetailsService()
        )
        guard let asset = await assetResolver.resolveAsset(for: assetId, multichainState: multichainState) else {
            guard let onUnavailable else {
                ToastPresenter.showToast(
                    configuration: ToastPresenter.Configuration(
                        title: TKLocales.Trade.Assets.Errors.load
                    )
                )
                return
            }
            Log.w("multichain ramp unavailable for fee asset \(assetId), falling back to receive")
            onUnavailable()
            return
        }

        openMultichainRamp(
            mode: .deposit(asset),
            wallet: wallet,
            presentingViewController: presentingViewController,
            onDismiss: onDismiss
        )
    }

    func openDepositTon(wallet: Wallet, entrySource: DepositAnalyticsSource) {
        let presentingViewController = router.rootViewController
        let reloadBalance: () -> Void = { [weak self] in
            guard let balanceLoader = self?.keeperCoreMainAssembly.loadersAssembly.balanceLoader else { return }
            Task {
                await balanceLoader.reloadBalance(wallet: wallet, priority: .userInitiated)
            }
        }

        guard wallet.isMultichain else {
            openRamp(
                flow: .deposit,
                wallet: wallet,
                initialDeeplink: RampDeeplinkParameters(
                    fromToken: TonInfo.symbol,
                    toToken: nil,
                    toNetwork: nil,
                    fromNetwork: "NATIVE",
                    cashMethod: nil,
                    itemType: .fiat
                ),
                entrySource: entrySource,
                presentingViewController: presentingViewController,
                onDismiss: reloadBalance
            )
            return
        }

        Task { [weak self] in
            guard let self else { return }
            await openMultichainOnrampFromAsset(
                wallet: wallet,
                assetId: MultichainChain.ton.defaultSendAssetId,
                presentingViewController: presentingViewController,
                onDismiss: reloadBalance
            )
        }
    }

    func openMultichainRamp(
        mode: MultichainRampCoordinator.Mode,
        wallet: Wallet,
        presentingViewController: UIViewController? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
        let rampRouter = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = MultichainRampCoordinator(
            mode: mode,
            router: rampRouter,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            multichainRampService: keeperCoreMainAssembly.servicesAssembly.multichainRampService()
        )

        var isFlowFinished = false
        weak var presentationDelegate: ModalPresentationDelegate?
        let finishFlow: () -> Void = { [weak self, weak coordinator] in
            guard !isFlowFinished else { return }
            isFlowFinished = true
            self?.clearModalPresentationDelegate(presentationDelegate)
            self?.removeChild(coordinator)
            onDismiss?()
        }

        coordinator.didTapReceiveTokens = { [weak self] wallet in
            guard let self else { return }
            openReceive(
                tokens: getRampTokens(wallet: wallet),
                wallet: wallet
            )
        }

        coordinator.didTapOpenMerchant = { [weak self, weak navigationController] url in
            guard let self, let navigationController else { return }
            self.openBuySellItemURL(url, fromViewController: navigationController)
        }

        let isCustomPresentation = presentingViewController != nil
        coordinator.didClose = { [weak self, weak navigationController] in
            if isCustomPresentation {
                navigationController?.dismiss(animated: true)
            } else {
                self?.router.dismiss()
            }
            finishFlow()
        }

        addChild(coordinator)
        coordinator.start()

        if let presentingViewController {
            presentationDelegate = presentModally(
                navigationController,
                from: presentingViewController,
                onDismiss: finishFlow
            )
        } else {
            router.dismiss(animated: true) { [weak self] in
                self?.router.present(navigationController, onDismiss: finishFlow)
            }
        }
    }

    func getRampTokens(wallet: Wallet) -> [Token] {
        let balanceStore = keeperCoreMainAssembly.storesAssembly.balanceStore
        let tronBalanceIsZero = balanceStore.getState()[wallet]?.walletBalance.tronBalance?.amount.isZero ?? true
        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
        let tronDisabled = configuration.flag(\.tronDisabled, network: wallet.network) && tronBalanceIsZero

        var tokens: [Token] = [.ton(.ton)]
        if !tronDisabled, wallet.tron != nil {
            tokens.append(.tron(.usdt))
        }

        return tokens
    }

    func openReceive(
        tokens: [Token],
        wallet: Wallet,
        completion: (() -> Void)? = nil,
        onDidDisplayToken: ((Token) -> Void)? = nil
    ) {
        let coordinator = receiveModule()
            .createReceiveCoordinator(
                router: router,
                tokens: tokens,
                wallet: wallet,
                didDisplayToken: onDidDisplayToken
            )

        startReceiveCoordinator(coordinator, completion: completion)
    }

    func openReceive(
        token: Token,
        wallet: Wallet,
        completion: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        guard let coordinator = receiveModule()
            .createReceiveCoordinator(
                router: router,
                token: token,
                wallet: wallet
            )
        else {
            // A caller waiting to hear the screen closed is waiting for something that will never
            // open, and a fee refill routes here as its own last resort.
            completion?()
            onClose?()
            return
        }

        startReceiveCoordinator(coordinator, completion: completion, onClose: onClose)
    }

    func openReceive(
        wallet: Wallet,
        address: ReceiveAddressPreview,
        completion: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        let coordinator = receiveModule()
            .createReceiveCoordinator(
                router: router,
                wallet: wallet,
                address: address
            )

        startReceiveCoordinator(coordinator, completion: completion, onClose: onClose)
    }

    private func receiveModule() -> ReceiveModule {
        ReceiveModule(
            dependencies: .init(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
    }

    private func startReceiveCoordinator(
        _ coordinator: ReceiveCoordinator,
        completion: (() -> Void)?,
        onClose: (() -> Void)? = nil
    ) {
        coordinator.didClose = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
            onClose?()
        }

        addChild(coordinator)
        coordinator.start()
        completion?()
    }

    func openStake(wallet: Wallet, initiatedBy: InitiatedBy, utm: UtmParameters = .empty) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = StakingCoordinator(
            wallet: wallet,
            initiatedBy: initiatedBy,
            utm: utm,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )

        coordinator.didFinish = { [weak self] in
            self?.router.dismiss()
            self?.removeChild($0)
        }

        coordinator.didClose = { [weak self, weak coordinator] in
            self?.router.dismiss()
            self?.removeChild(coordinator)
        }

        self.stakingCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: nil)

        self.router.dismiss(animated: true) { [weak self, weak coordinator] in
            self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
            })
        }
    }

    func openBuy(
        wallet: Wallet,
        isInternalPurchasing: Bool,
        entrySource: DepositAnalyticsSource,
        utm: UtmParameters = .empty
    ) {
        if isInternalPurchasing {
            openDeposit(wallet: wallet, entrySource: entrySource, utm: utm)
        } else {
            openBrowserDefiFlow()
        }
    }

    func openBuy(wallet: Wallet, entrySource: DepositAnalyticsSource, utm: UtmParameters = .empty) {
        openDeposit(wallet: wallet, entrySource: entrySource, utm: utm)
    }

    func openDeposit(
        wallet: Wallet,
        entrySource: DepositAnalyticsSource,
        initialDeeplink: RampDeeplinkParameters? = nil,
        utm: UtmParameters = .empty
    ) {
        if wallet.isMultichain {
            openMultichainRamp(mode: .deposit(nil), wallet: wallet)
        } else {
            openRamp(
                flow: .deposit,
                wallet: wallet,
                initialDeeplink: initialDeeplink,
                entrySource: entrySource,
                utm: utm
            )
        }
    }

    func openWithdraw(
        wallet: Wallet,
        entrySource: DepositAnalyticsSource,
        initialDeeplink: RampDeeplinkParameters? = nil,
        utm: UtmParameters = .empty
    ) {
        if wallet.isMultichain {
            openSendWithTokenPicker(
                wallet: wallet,
                sendSource: sendAnalyticsSource(for: entrySource, utm: utm)
            )
            return
        }

        openRamp(
            flow: .withdraw,
            wallet: wallet,
            initialDeeplink: initialDeeplink,
            entrySource: entrySource,
            utm: utm
        )
    }

    func openHistoryEventDetails(
        wallet: Wallet,
        event: AccountEventDetailsEvent,
        network: Network,
        fromViewController: UIViewController?
    ) {
        let module = HistoryEventDetailsAssembly.module(
            wallet: wallet,
            event: .ton(event),
            keeperCoreAssembly: keeperCoreMainAssembly,
            network: network
        )
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

        module.output.didSelectEncryptedComment = { [weak self] wallet, payload, eventId in
            self?.decryptComment(wallet: wallet, payload: payload, eventId: eventId)
        }

        module.output.didFinish = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        module.output.didTapTransactionDetails = { [weak self] url, title in
            self?.openDapp(
                title: title,
                url: url,
                analyticsFrom: .history
            )
        }
        if let fromViewController {
            bottomSheetViewController.present(fromViewController: fromViewController)
        } else {
            router.rootViewController.dismiss(animated: true) { [weak self] in
                guard let router = self?.router else { return }
                bottomSheetViewController.present(fromViewController: router.rootViewController)
            }
        }
    }

    func openTronEventDetails(
        wallet: Wallet,
        event: TronTransaction,
        network: Network,
        fromViewController: UIViewController?
    ) {
        let module = HistoryEventDetailsAssembly.module(
            wallet: wallet,
            event: .tron(event),
            keeperCoreAssembly: keeperCoreMainAssembly,
            network: network
        )
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

        module.output.didFinish = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        module.output.didTapTransactionDetails = { [weak self] url, title in
            self?.openDapp(
                title: title,
                url: url,
                analyticsFrom: .history
            )
        }

        if let fromViewController {
            bottomSheetViewController.present(fromViewController: fromViewController)
        } else {
            router.rootViewController.dismiss(animated: true) { [weak self] in
                guard let router = self?.router else { return }
                bottomSheetViewController.present(fromViewController: router.rootViewController)
            }
        }
    }

    func openBackup(wallet: Wallet, source: BackupSource) {
        guard let navigationController = router.rootViewController.navigationController else { return }
        let configuration = SettingsListBackupConfigurator(
            wallet: wallet,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        configuration.didTapBackupManually = { [weak self, weak navigationController] in
            self?.openManuallyBackup(wallet: wallet, source: source) {
                guard source == .walletSetupSection else { return }
                navigationController?.popViewController(animated: true)
            }
        }

        configuration.didTapShowRecoveryPhrase = { [weak self] in
            self?.openRecoveryPhrase(wallet: wallet)
        }

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak navigationController] in
            navigationController?.popViewController(animated: true)
        }

        navigationController.pushViewController(module.viewController, animated: true)
    }

    func openBattery(
        wallet: Wallet,
        jettonMasterAddress: TonSwift.Address? = nil,
        keepCurrentModal: Bool = false,
        initiatedBy: InitiatedBy,
        utm: UtmParameters = .empty,
        onRechargeSuccess: (() -> Void)? = nil
    ) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = BatteryRefillCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet,
            jettonMasterAddress: jettonMasterAddress,
            initiatedBy: initiatedBy,
            utm: utm,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didOpenRefundURL = { [weak self] url, title in
            if wallet.isMultichain {
                self?.openBatteryWeb(wallet: wallet, url: url, title: title)
            } else {
                self?.openDapp(title: title, url: url, analyticsFrom: .deepLink)
            }
        }

        coordinator.didRechargeSuccess = { [weak self, weak navigationController, weak coordinator] in
            if keepCurrentModal {
                navigationController?.dismiss(
                    animated: true,
                    completion: { [weak self, weak coordinator] in
                        self?.removeChild(coordinator)
                        onRechargeSuccess?()
                    }
                )
            } else {
                self?.openHistory()
            }
        }

        coordinator.didFinish = { [weak self, weak navigationController] in
            if keepCurrentModal {
                navigationController?.dismiss(animated: true)
            } else {
                self?.router.dismiss()
            }
            self?.removeChild($0)
        }

        self.batteryRefillCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: nil)

        if keepCurrentModal {
            self.router.presentOverTopPresented(
                navigationController,
                completion: {
                    coordinator.didAppear()
                },
                onDismiss: { [weak self, weak coordinator] in
                    self?.removeChild(coordinator)
                }
            )
        } else {
            self.router.dismiss(animated: true) { [weak self, coordinator] in
                self?.router.present(
                    navigationController,
                    completion: {
                        coordinator.didAppear()
                    },
                    onDismiss: { [weak self, weak coordinator] in
                        self?.removeChild(coordinator)
                    }
                )
            }
        }
    }

    func openRecoveryPhrase(wallet: Wallet) {
        guard let navigationController = router.rootViewController.navigationController else { return }
        let coordinator = SettingsRecoveryPhraseCoordinator(
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openManuallyBackup(
        wallet: Wallet,
        source: BackupSource,
        onComplete: (() -> Void)? = nil
    ) {
        guard let navigationController = router.rootViewController.navigationController else { return }
        let coordinator = BackupModule(
            dependencies: BackupModule.Dependencies(
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )
        ).createBackupCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet,
            source: source
        )

        coordinator.didCompleteBackup = onComplete
        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openInsufficientFundsPopup(configuration: InfoPopupBottomSheetViewController.Configuration) {
        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
        viewController.configuration = configuration
        router.dismiss(animated: true) { [router] in
            bottomSheetViewController.present(fromViewController: router.rootViewController)
        }
    }

    func openUnverifiedTokenInfoPopup() {
        PopupContentPresenter.presentUnverifiedToken(
            from: router.rootViewController.topPresentedViewController()
        )
    }

    func openVerifiedTokenInfoPopup() {
        PopupContentPresenter.presentVerifiedToken(
            from: router.rootViewController.topPresentedViewController()
        )
    }

    private nonisolated static var preservePresentedStackKey: String {
        "preservePresentedStack"
    }

    private func openHistory(fromNavigationController: UINavigationController? = nil) {
        guard let coordinator = createStandaloneHistoryCoordinator(navigationController: fromNavigationController) else {
            return
        }
        standaloneHistoryCoordinator.map(removeChild)
        standaloneHistoryCoordinator = coordinator
        addChild(coordinator)
        if fromNavigationController != nil {
            coordinator.start()
        } else {
            router.dismiss(animated: true) {
                coordinator.start()
            }
        }
    }

    private func openBrowserTab() {
        guard let browserViewController = browserCoordinator?.router.rootViewController else { return }
        _ = openDeeplinkTab(
            for: browserViewController
        )
    }

    private func openMainDeeplink() {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let walletViewController = walletTabNavigationCoordinator()?.router.rootViewController else { return }
        _ = openDeeplinkTab(
            for: walletViewController
        )
    }

    private func openBrowserTabExplore(network: MultichainChain? = nil) {
        openBrowserTab()
        browserCoordinator?.openExplore()
        if let network {
            browserCoordinator?.selectExploreNetworkFilter(network)
        }
    }

    private func openBrowserDefiFlow() {
        openBrowserTab()
        browserCoordinator?.openDefi()
    }

    @discardableResult
    private func openTradeTab(completion: (() -> Void)? = nil) -> Bool {
        guard let tradeViewController = tradeCoordinator?.router.rootViewController else { return false }
        return openDeeplinkTab(
            for: tradeViewController,
            beforeTabSelect: { [weak self] in
                self?.tradeCoordinator?.openRoot(animated: false)
            },
            completion: completion
        )
    }

    @discardableResult
    private func openDeeplinkTab(
        for viewController: UIViewController,
        beforeTabSelect: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) -> Bool {
        guard let index = router.rootViewController.viewControllers?.firstIndex(of: viewController) else {
            return false
        }
        router.rootViewController.navigationController?.popToRootViewController(animated: true)
        beforeTabSelect?()
        selectTab(at: index)
        if router.rootViewController.presentedViewController != nil {
            router.dismiss(animated: true, completion: completion)
        } else {
            completion?()
        }
        return true
    }

    private func selectTab(at index: Int) {
        router.rootViewController.selectedIndex = index
        router.rootViewController.playAnimatedTabBarItem(at: index)
    }

    private func openTradingDeeplink(
        gridID: String?,
        source: TradeFlowAnalyticsSource
    ) -> Bool {
        guard openTradeTab(completion: { [weak self] in
            if let gridID {
                self?.tradeCoordinator?.scrollToGrid(id: gridID)
            }
        }) else {
            return false
        }

        coreAssembly.analyticsProvider.log(
            TradeStarted(from: source.tradeStarted)
        )
        return true
    }

    private func openTradeAssetDeeplink(
        assetID: String,
        source: AssetViewAnalyticsSource
    ) -> Bool {
        return openTradeTab { [weak self] in
            self?.tradeCoordinator?.openAssetDetails(
                assetID: assetID,
                source: source
            )
        }
    }

    private func tradeFlowAnalyticsSource(for sendSource: SendAnalyticsSource) -> TradeFlowAnalyticsSource {
        switch sendSource {
        case .qrCode:
            .qrCode
        default:
            .deepLink
        }
    }

    func depositAnalyticsSource(for sendSource: SendAnalyticsSource) -> DepositAnalyticsSource {
        switch sendSource {
        case .walletScreen:
            .walletScreen
        case .jettonScreen:
            .jettonScreen
        case .deepLink:
            .deepLink
        case .qrCode:
            .qrCode
        case .tonconnectLocal, .tonconnectRemote:
            .deepLink
        }
    }

    func depositAnalyticsSource(for initiatedBy: InitiatedBy) -> DepositAnalyticsSource {
        switch initiatedBy {
        case .user:
            .walletScreen
        case .deepLink:
            .deepLink
        case .qrCode:
            .qrCode
        case .tonconnectLocal, .tonconnectRemote, .walletconnect, .evmInjected:
            .deepLink
        }
    }

    private func sendAnalyticsSource(
        for entrySource: DepositAnalyticsSource,
        utm: UtmParameters = .empty
    ) -> SendAnalyticsSource {
        switch entrySource {
        case .walletScreen, .historyScreen, .browser, .collectibles:
            .walletScreen
        case .jettonScreen:
            .jettonScreen
        case .deepLink:
            .deepLink(utm: utm)
        case .qrCode:
            .qrCode
        }
    }

    private func assetViewAnalyticsSource(for sendSource: SendAnalyticsSource) -> AssetViewAnalyticsSource {
        switch sendSource {
        case .qrCode:
            .qrCode
        default:
            .deepLink
        }
    }

    private func decryptComment(
        wallet: Wallet,
        payload: EncryptedCommentPayload,
        eventId: String
    ) {
        DecryptCommentHandler.decryptComment(
            wallet: wallet,
            payload: payload,
            eventId: eventId,
            parentCoordinator: self,
            parentRouter: router,
            keeperCoreAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )
    }

    var isActiveWalletMultichain: Bool {
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
            return false
        }
        return wallet.isMultichain
    }

    private func openCryptoAssetsFromWallet() {
        guard
            let tradeCoordinator,
            let targetNavigationController = (
                router.rootViewController.selectedViewController as? UINavigationController
            ) ?? walletTabNavigationCoordinator()?.router.rootViewController
        else {
            return
        }

        tradeCoordinator.openAssetList(
            initialCategory: .all,
            tradeFlowAnalyticsSource: .walletScreen,
            on: targetNavigationController
        )
    }

    private func walletTabNavigationCoordinator() -> RouterCoordinator<NavigationControllerRouter>? {
        if isActiveWalletMultichain {
            multichainWalletCoordinator ?? walletCoordinator
        } else {
            walletCoordinator ?? multichainWalletCoordinator
        }
    }

    private func walletTabCoordinatorOutput() -> WalletTabCoordinatorOutput? {
        if isActiveWalletMultichain {
            multichainWalletCoordinator ?? walletCoordinator
        } else {
            walletCoordinator ?? multichainWalletCoordinator
        }
    }

    private func handleWalletCollectiblesPublishDeeplink(sign: Data) -> Bool {
        if let walletCoordinator,
           walletCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
        {
            return true
        }
        if let multichainWalletCoordinator,
           multichainWalletCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
        {
            return true
        }
        return false
    }

    private func didOpenAppWithPushNotificationTapHandler(userInfo: [AnyHashable: Any]?) {
        areLaunchStoriesSuppressed = true
        cancelBootConfigurationStories()

        let pushId = userInfo?["push_id"] as? String
        let link = userInfo?["link"] as? String
        let dappUrl = userInfo?["dapp_url"] as? String
        let deeplink = userInfo?["deeplink"] as? String

        let resolvedDeeplink: String?
        let utm: UtmParameters
        if let link, let linkURL = URL(string: link) {
            resolvedDeeplink = link
            utm = UtmParameters(link: link)
            if let deeplink = try? keeperCoreMainAssembly.deeplinkParser.parse(
                string: link,
                source: .browser
            ), handleDeeplink(
                deeplink: deeplink,
                fromStories: false,
                dappOpenFrom: .push,
                utm: utm
            ) {
                // Push delivered a tonkeeper deeplink — handled above.
            } else {
                openURL(linkURL, title: nil)
            }
        } else if let dappUrl, let dappUrlURL = URL(string: dappUrl) {
            resolvedDeeplink = dappUrl
            utm = UtmParameters(link: dappUrl)
            openDapp(title: nil, url: dappUrlURL, analyticsFrom: .push, utm: utm)
        } else {
            let deeplink = link ?? dappUrl ?? deeplink
            resolvedDeeplink = deeplink
            utm = UtmParameters(link: deeplink)
            _ = self.handleDeeplink(
                deeplink: deeplink,
                fromStories: false,
                dappOpenFrom: .push,
                utm: utm
            )
        }

        coreAssembly.analyticsProvider.log(
            PushClick(
                pushId: pushId,
                deepLink: resolvedDeeplink.map(Self.removePrivateDataFromUrl)
            ),
            utm: utm
        )
    }

    private static let regexPrivateData = try! NSRegularExpression(pattern: "[a-fA-F0-9]{64}|0:[a-fA-F0-9]{64}")

    private static func removePrivateDataFromUrl(_ url: String) -> String {
        let range = NSRange(url.startIndex..., in: url)
        return regexPrivateData.stringByReplacingMatches(in: url, range: range, withTemplate: "X")
    }
}

// MARK: - Ton Connect

// MARK: - AppStateTrackerObserver

extension MainCoordinator: AppStateTrackerObserver {
    func didUpdateState(_ state: TKCore.AppStateTracker.State) {
        switch appStateTracker.state {
        case .active:
            mainController.startUpdates()
        case .background:
            mainController.stopUpdates()
        case .resign:
            return
        }
    }
}

// MARK: - ReachabilityTrackerObserver

extension MainCoordinator: ReachabilityTrackerObserver {
    func didUpdateState(_ state: TKCore.ReachabilityTracker.State) {
        switch (appStateTracker.state, reachabilityTracker.state) {
        case (.active, .connected):
            mainController.reconnectUpdates()
        default:
            return
        }
    }
}

private extension MainCoordinator {
    @discardableResult
    func presentModally(
        _ viewController: UIViewController,
        from presentingViewController: UIViewController,
        onDismiss: @escaping () -> Void
    ) -> ModalPresentationDelegate {
        let delegate = ModalPresentationDelegate { [weak self] in
            self?.modalPresentationDelegate = nil
            onDismiss()
        }
        modalPresentationDelegate = delegate

        presentingViewController.topPresentedViewController().present(viewController, animated: true) {
            viewController.presentationController?.delegate = delegate
        }
        return delegate
    }

    /// A programmatic dismissal never reaches `presentationControllerDidDismiss`, so a flow that
    /// closes itself has to release its delegate. Identity keeps it from dropping a newer presentation.
    func clearModalPresentationDelegate(_ delegate: ModalPresentationDelegate?) {
        guard let delegate, modalPresentationDelegate === delegate else { return }
        modalPresentationDelegate = nil
    }
}

private final class ModalPresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}
