import BigInt
import KeeperCore
import SafariServices
import Stories
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

final class MainCoordinator: RouterCoordinator<TabBarControllerRouter> {
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    let coreAssembly: TKCore.CoreAssembly
    let mainController: KeeperCore.MainController

    private let mainCoordinatorStateManager: MainCoordinatorStateManager
    var mainCoordinatorStoriesController: MainCoordinatorStoriesController?

    private let walletModule: WalletModule
    private let historyModule: HistoryModule
    private let browserModule: BrowserModule
    private let collectiblesModule: CollectiblesModule

    private var walletCoordinator: WalletCoordinator?
    private var historyCoordinator: HistoryCoordinator?
    var browserCoordinator: BrowserCoordinator?
    private var collectiblesCoordinator: CollectiblesCoordinator?

    weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
    private weak var addWalletCoordinator: AddWalletCoordinator?
    private weak var sendTokenCoordinator: SendTokenCoordinator?
    private weak var webSwapCoordinator: WebSwapCoordinator?
    private weak var batteryRefillCoordinator: BatteryRefillCoordinator?
    private weak var topUpCoordinator: TopUpCoordinator?
    private weak var stakingCoordinator: StakingCoordinator?
    private weak var stakingStakeCoordinator: StakingStakeCoordinator?
    private weak var stakingUnstakeCoordinator: StakingUnstakeCoordinator?
    private weak var stakingConfirmationCoordinator: StakingConfirmationCoordinator?
    private weak var nativeSwapCoordinator: NativeSwapCoordinator?

    private let appStateTracker: AppStateTracker
    private let reachabilityTracker: ReachabilityTracker
    let recipientResolver: RecipientResolver
    let insufficientFundsValidator: InsufficientFundsValidator
    private let cookiesController: KeeperCore.CookiesController

    var deeplinkHandleTask: Task<Void, Never>?

    private var sendTransactionNotificationToken: NSObjectProtocol?
    private var openPushNotificationNotificationToken: NSObjectProtocol?

    private var deeplinkRouter: ContainerViewControllerRouter<UIViewController>?

    init(
        router: TabBarControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        appStateTracker: AppStateTracker,
        reachabilityTracker: ReachabilityTracker,
        recipientResolver: RecipientResolver,
        insufficientFundsValidator: InsufficientFundsValidator
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.mainController = keeperCoreMainAssembly.mainController()
        self.walletModule = WalletModule(
            dependencies: WalletModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        self.historyModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        self.browserModule = BrowserModule(
            dependencies: BrowserModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        self.collectiblesModule = CollectiblesModule(
            dependencies: CollectiblesModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        self.appStateTracker = appStateTracker
        self.reachabilityTracker = reachabilityTracker
        self.recipientResolver = recipientResolver
        self.insufficientFundsValidator = insufficientFundsValidator

        self.mainCoordinatorStateManager = MainCoordinatorStateManager(
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            walletNFTStoreProvider: { wallet in
                keeperCoreMainAssembly.storesAssembly.walletNFTsStore(wallet: wallet, nftService: keeperCoreMainAssembly.servicesAssembly.accountNftService())
            }
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
                    openHistoryTab()
                    if let wallet = notification.userInfo?["wallet"] as? Wallet {
                        Task {
                            await keeperCoreMainAssembly.storesAssembly.walletsStore.makeWalletActive(wallet)
                        }
                    }
                }
            }

        router.didSelectItem = { [weak self] index in
            guard let self else { return }
            let viewControllers = self.router.rootViewController.viewControllers ?? []
            guard viewControllers.count > index else { return }
            let viewController = viewControllers[index]
            if viewController === browserCoordinator?.router.rootViewController {
                coreAssembly.analyticsProvider.log(
                    eventKey: .openBrowser
                )
            }
        }

        openPushNotificationNotificationToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "PushNotificationOpen"),
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor [weak self] in
                self?.didOpenAppWithPushNotificationTapHandler(userInfo: notification.userInfo)
            }
        }
    }

    deinit {
        if let sendTransactionNotificationToken {
            NotificationCenter.default.removeObserver(sendTransactionNotificationToken)
        }
        if let openPushNotificationNotificationToken {
            NotificationCenter.default.removeObserver(openPushNotificationNotificationToken)
        }
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
        mainController.start()
        try? setupTONWalletKitIfNeeded()
        DispatchQueue.main.async {
            _ = self.handleDeeplink(deeplink: deeplink, fromStories: false)
            self.setupStoriesController()
        }
    }

    func handleDeeplink(deeplink: CoordinatorDeeplink?, fromStories: Bool) -> Bool {
        switch deeplink {
        case let tonkeeperDeeplink as KeeperCore.Deeplink:
            return handleTonkeeperDeeplink(tonkeeperDeeplink, fromStories: fromStories, sendSource: .deepLink)
        case let string as String:
            do {
                let deeplink = try mainController.parseDeeplink(deeplink: string)
                return handleTonkeeperDeeplink(deeplink, fromStories: fromStories, sendSource: .deepLink)
            } catch {
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: error.localizedDescription))
                return false
            }
        default:
            return false
        }
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
        walletCoordinator.didTapScan = { [weak self] in
            self?.openScan()
        }

        walletCoordinator.didTapWalletButton = { [weak self] in
            self?.openWalletPicker()
        }

        walletCoordinator.didTapSend = { [weak self] wallet, token in
            self?.openSend(
                wallet: wallet,
                sendInput: .direct(item: .ton(.token(token, amount: 0))),
                sendSource: .walletScreen,
                comment: nil
            )
        }

        walletCoordinator.didTapSwap = { [weak self] wallet in
            self?.openSwap(wallet: wallet, token: .ton(.ton))
        }

        walletCoordinator.didTapSupportButton = { [weak self] in
            self?.openSupport()
        }

        walletCoordinator.didTapSettingsButton = { [weak self] wallet in
            self?.openSettings(wallet: wallet)
        }

        walletCoordinator.didSelectTonDetails = { [weak self] in
            self?.openTonDetails(wallet: $0)
        }

        walletCoordinator.didSelectJettonDetails = { [weak self] wallet, jettonItem, hasPrice in
            self?.openJettonDetails(jettonItem: jettonItem, wallet: wallet, hasPrice: hasPrice)
        }

        walletCoordinator.didSelectTronUSDTDetails = { [weak self] wallet in
            self?.openTronUSDTDetails(wallet: wallet)
        }

        walletCoordinator.didSelectEthenaDetails = { [weak self] wallet in
            self?.openEthenaDetails(wallet: wallet)
        }

        walletCoordinator.didSelectStakingItem = { [weak self] wallet, stakingPoolInfo, _ in
            self?.openStakingItemDetails(
                wallet: wallet,
                stakingPoolInfo: stakingPoolInfo
            )
        }

        walletCoordinator.didSelectCollectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStackingInfo in
            self?.openStakingCollect(
                wallet: wallet,
                stakingPoolInfo: stakingPoolInfo,
                accountStackingInfo: accountStackingInfo
            )
        }

        walletCoordinator.didTapDeposit = { [weak self] tokens, wallet in
            self?.openRamp(flow: .deposit, tokens: tokens, wallet: wallet)
        }

        walletCoordinator.didTapWithdraw = { [weak self] tokens, wallet in
            self?.openRamp(flow: .withdraw, tokens: tokens, wallet: wallet)
        }

        walletCoordinator.didTapBuy = { [weak self] wallet in
            self?.openBuy(wallet: wallet)
        }

        walletCoordinator.didTapReceive = { [weak self] tokens, wallet in
            self?.openReceive(tokens: tokens, wallet: wallet)
        }

        walletCoordinator.didTapStake = { [weak self] wallet in
            self?.openStake(wallet: wallet)
        }

        walletCoordinator.didTapStory = { [weak self] story in
            self?.presentStory(story: story)
        }

        walletCoordinator.didTapAllUpdates = { [weak self] in
            self?.openAllUpdates()
        }

        walletCoordinator.didTapBackup = { [weak self] wallet in
            self?.openBackup(wallet: wallet)
        }

        walletCoordinator.didTapBattery = { [weak self] wallet in
            self?.openBattery(
                wallet: wallet
            )
        }

        walletCoordinator.didTapStoriesOnboarding = { [weak self] storyId in
            _ = self?.handleTonkeeperDeeplink(
                .story(storyId: storyId),
                fromStories: false, sendSource: .deepLink
            )
        }

        let historyCoordinator = historyModule.createHistoryCoordinator()
        historyCoordinator.didOpenTonEventDetails = { [weak self] wallet, event, network in
            self?.openHistoryEventDetails(wallet: wallet, event: event, network: network)
        }
        historyCoordinator.didOpenTronEventDetails = { [weak self] wallet, event, network in
            self?.openTronEventDetails(wallet: wallet, event: event, network: network)
        }
        historyCoordinator.didDecryptComment = { [weak self] wallet, payload, eventId in
            self?.decryptComment(wallet: wallet, payload: payload, eventId: eventId)
        }
        historyCoordinator.didOpenDapp = { [weak self] url, title in
            self?.openDapp(title: title, url: url)
        }
        historyCoordinator.didOpenBuySellItem = { [weak self] url, fromViewController in
            self?.openBuySellItemURL(url, fromViewController: fromViewController)
        }
        historyCoordinator.passcodeProvider = getPasscode

        let browserCoordinator = browserModule.createBrowserCoordinator()

        browserCoordinator.didHandleDeeplink = { [weak self] deeplink in
            _ = self?.handleTonkeeperDeeplink(deeplink, fromStories: false, sendSource: .deepLink)
        }

        browserCoordinator.didRequestOpenBuySell = { [weak self] wallet in
            self?.openBuy(wallet: wallet)
        }

        let collectiblesCoordinator = collectiblesModule.createCollectiblesCoordinator(parentRouter: router)
        collectiblesCoordinator.didOpenDapp = { url, title in
            self.openDapp(title: title, url: url)
        }
        collectiblesCoordinator.didRequestDeeplinkHandling = { [weak self] deeplink in
            _ = self?.handleTonkeeperDeeplink(deeplink, fromStories: false, sendSource: .deepLink)
        }
        collectiblesCoordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing, wallet in
            self?.openBuy(wallet: wallet, isInternalPurchasing: isInternalPurchasing)
        }

        self.walletCoordinator = walletCoordinator
        self.historyCoordinator = historyCoordinator
        self.browserCoordinator = browserCoordinator
        self.collectiblesCoordinator = collectiblesCoordinator

        addChild(walletCoordinator)
        addChild(historyCoordinator)
        addChild(browserCoordinator)
        addChild(collectiblesCoordinator)

        walletCoordinator.start()
        historyCoordinator.start()
        browserCoordinator.start()
        collectiblesCoordinator.start()
    }

    func handleStateUpdate(_ state: MainCoordinatorStateManager.State) {
        let viewControllers = state.tabs.compactMap { tab -> RouterCoordinator<NavigationControllerRouter>? in
            switch tab {
            case .wallet:
                return walletCoordinator
            case .history:
                return historyCoordinator
            case .browser:
                return browserCoordinator
            case .purchases:
                return collectiblesCoordinator
            }
        }.map { $0.router.rootViewController }

        router.rootViewController.setViewControllers(viewControllers, animated: false)
    }

    func setupTabBarTaps() {
        (router.rootViewController as? TKTabBarController)?.didLongPressTabBarItem = { [weak self] index in
            guard index == 0 else { return }
            self?.openWalletPicker()
        }
    }

    func openScan() {
        let extensions = keeperCoreMainAssembly.configurationAssembly.configuration.value(\.qrScannerExtensions)
        let scanModule = ScannerModule(
            dependencies: ScannerModule.Dependencies(
                coreAssembly: coreAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
            )
        ).createScannerModule(
            configurator: DefaultScannerControllerConfigurator(extensions: extensions ?? []),
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

        scanModule.output.didFailScan = { [weak self] error in
            ToastPresenter.hideAll()
            guard let error else { return }
            ToastPresenter.showToast(configuration: .init(title: error))
            self?.router.dismiss()
        }

        router.present(navigationController)
    }

    func openSend(
        wallet: Wallet,
        sendInput: SendInput,
        sendSource: SendAnalyticsSource,
        recipient: Recipient? = nil,
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
                guard let successReturn else { return }
                self?.openURL(successReturn, title: nil)
            })
            self?.removeChild($0)
        }

        sendTokenCoordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            self?.openBuy(wallet: wallet, isInternalPurchasing: isInternalPurchasing)
        }
        sendTokenCoordinator.didRequestRefill = { [weak self] token in
            guard let self else { return }
            router.dismiss(animated: true) { [weak self] in
                self?.openReceive(tokens: [token], wallet: wallet)
            }
        }
        sendTokenCoordinator.didRequestOpenBattery = { [weak self] in
            self?.openBattery(wallet: wallet)
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
            self?.openHistoryTab()
        }

        sendTokenCoordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            self?.openBuy(wallet: wallet, isInternalPurchasing: isInternalPurchasing)
        }
        sendTokenCoordinator.didRequestRefill = { [weak self] token in
            guard let self else { return }
            router.dismiss(animated: true) { [weak self] in
                self?.openReceive(tokens: [token], wallet: wallet)
            }
        }
        sendTokenCoordinator.didRequestOpenBattery = { [weak self] in
            self?.openBattery(wallet: wallet)
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
                    toToken: toToken
                )
            } else {
                openNativeSwap(
                    wallet: wallet,
                    fromToken: fromToken,
                    toToken: toToken
                )
            }
        case .tron:
            openTRC20Swap()
        }
    }

    func openNativeSwap(
        wallet: Wallet,
        fromToken: String? = nil,
        toToken: String? = nil
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
            fromToken: fromToken,
            toToken: toToken,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )

        nativeSwapCoordinator = coordinator

        coordinator.didFinish = { [weak self, weak coordinator] _ in
            guard let self, let coordinator else { return }

            router.dismiss()
            removeChild(coordinator)
        }

        coordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            guard let self else { return }

            openBuy(wallet: wallet, isInternalPurchasing: isInternalPurchasing)
        }

        addChild(coordinator)
        coordinator.start()

        router.dismiss(animated: true) { [weak self] in
            self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
            })
        }
    }

    func openWebSwap(
        wallet: Wallet,
        fromToken: String? = nil,
        toToken: String? = nil
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

        router.dismiss(animated: true) { [weak self] in
            self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
            })
        }
    }

    private var trc20SwapOpenTask: Task<Void, Swift.Error>?
    func openTRC20Swap() {
        trc20SwapOpenTask?.cancel()
        trc20SwapOpenTask = Task { [weak self] in
            guard let self else { return }

            let service = keeperCoreMainAssembly.buySellAssembly.buySellMethodsService()
            guard let methods = try? await service.loadFiatMethods(countryCode: nil) else { return }

            if Task.isCancelled { return }

            guard let url = methods.buy
                .flatMap(\.items)
                .first(where: { $0.id == "letsexchange_buy_swap" })
                .flatMap({ URL(string: $0.actionButton.url) })
            else { return }

            openURL(url, title: nil)
        }
    }

    func handleTonkeeperDeeplink(_ deeplink: KeeperCore.Deeplink, fromStories: Bool, sendSource: SendAnalyticsSource) -> Bool {
        switch deeplink {
        case let .transfer(data):
            switch data {
            case let .sendTransfer(sendTransferData):
                openSendDeeplink(
                    recipient: sendTransferData.recipient,
                    amount: sendTransferData.amount,
                    comment: sendTransferData.comment,
                    jettonAddress: sendTransferData.jettonAddress,
                    expirationTimestamp: sendTransferData.expirationTimestamp,
                    successReturn: sendTransferData.successReturn,
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
                    expirationTimestamp: signRawTransferData.expirationTimestamp
                )
                return true
            }
        case .buyTon:
            openBuyDeeplink()
            return true
        case .staking:
            openStakingDeeplink()
            return true
        case let .pool(poolAddress):
            openPoolDetailsDeeplink(poolAddress: poolAddress)
            return true
        case let .exchange(provider):
            openExchangeDeeplink(provider: provider)
            return true
        case let .swap(data):
            openSwapDeeplink(fromToken: data.fromToken, toToken: data.toToken)
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
            if let collectiblesCoordinator = collectiblesCoordinator,
               collectiblesCoordinator.handleTonkeeperDeeplink(deeplink: deeplink)
            {
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
        case let .dapp(dappURL):
            return handleDappDeeplink(url: dappURL)
        case .browser:
            openBrowserTabExplore()
            coreAssembly.analyticsProvider.log(
                eventKey: .openBrowser,
                args: ["from": fromStories ? "story" : "deep-link"]
            )
            return true
        case let .battery(battery):
            handleBatteryDeeplink(battery)
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
        }
    }

    // MARK: -  TODO: complete on next iteration: flow: .deeplink

    func handleTonConnectDeeplink(_ payload: TonConnectPayload) -> Bool {
        switch payload {
        case .empty:
            return false
        case let .withParameters(parameters, url):
            if keeperCoreMainAssembly.configurationAssembly.configuration.featureEnabled(.walletKitEnabled) {
                return handleTonConnectDeeplink(url: url)
            } else {
                return handleTonConnectDeeplink(parameters: parameters)
            }
        }
    }

    private func handleTonConnectDeeplink(url: URL) -> Bool {
        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)

        Task {
            do {
                try await keeperCoreMainAssembly.tonWalletKitAssembly.tonWalletKit.connect(url: url.absoluteString)

                await MainActor.run {
                    ToastPresenter.hideToast()
                }
            } catch {
                await MainActor.run {
                    ToastPresenter.hideToast()
                    ToastPresenter.showToast(
                        configuration: ToastPresenter.Configuration(
                            title: error.localizedDescription
                        )
                    )
                }
            }
        }
        return true
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
        Task {
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
                        self?.openDapp(title: manifest.name, url: manifest.url)
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
                    scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                    configurationAssembly: keeperCoreMainAssembly.configurationAssembly
                )
            ).createPairSignerDeeplinkCoordinator(
                publicKey: publicKey,
                name: name,
                router: NavigationControllerRouter(
                    rootViewController: navigationController
                )
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

    func openWalletPicker() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let module = WalletsListAssembly.module(
            model: WalletsPickerListModel(
                walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore
            ),
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            totalBalancesStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

        module.output.addButtonEvent = { [weak self, unowned bottomSheetViewController] in
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

        bottomSheetViewController.present(fromViewController: router.rootViewController)
    }

    func openAddWallet(router: ViewControllerRouter) {
        let module = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        )

        let coordinator = module.createAddWalletCoordinator(
            options: [.createRegular, .importRegular, .signer, .keystone, .ledger, .importWatchOnly, .importTestnet, .importTetra],
            router: router
        )
        coordinator.didAddWallets = { [weak self, weak coordinator] in
            self?.addWalletCoordinator = nil
            guard let coordinator else { return }
            self?.removeChild(coordinator)
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

    func openEditWallet(wallet: Wallet, fromViewController: UIViewController) {
        let addWalletModuleModule = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
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

        module.view.setupRightCloseButton { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        }

        fromViewController.present(navigationController, animated: true)
    }

    func openSupport() {
        let directSupportURL = keeperCoreMainAssembly.configurationAssembly.configuration.directSupportUrl
        let urlOpener = coreAssembly.urlOpener()
        let appSettings = coreAssembly.appSettings

        if appSettings.isSupportPopUpShown {
            guard let directSupportURL else { return }

            urlOpener.open(url: directSupportURL)
        } else {
            appSettings.isSupportPopUpShown = true
            let module = SupportPopupAssembly.module(directSupportURL: directSupportURL)
            let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
            bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())

            module.output.didOpenURL = { [weak bottomSheetViewController] in
                bottomSheetViewController?.dismiss()
                urlOpener.open(url: $0)
            }
            module.output.didClose = { [weak bottomSheetViewController] in
                bottomSheetViewController?.dismiss()
            }
        }
    }

    func openSettings(wallet: Wallet) {
        guard let navigationController = router.rootViewController.navigationController else { return }
        let module = SettingsModule(
            dependencies: SettingsModule.Dependencies(
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )
        )

        let router = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = module.createSettingsCoordinator(
            router: router,
            wallet: wallet
        )

        coordinator.didTapBattery = { [weak self] wallet in
            self?.openBattery(
                wallet: wallet
            )
        }

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openTonDetails(wallet: Wallet) {
        guard let navigationController = router.rootViewController.navigationController else { return }

        let historyListModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createTonHistoryListModule(wallet: wallet)

        historyListModule.output.didSelectEvent = { [weak self] event in
            switch event {
            case let .tonEvent(event):
                self?.openHistoryEventDetails(wallet: wallet, event: event, network: wallet.network)
            case let .tronEvent(event):
                self?.openTronEventDetails(wallet: wallet, event: event, network: wallet.network)
            }
        }

        let module = TokenDetailsAssembly.module(
            wallet: wallet,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            configurator: TonTokenDetailsConfigurator(
                wallet: wallet,
                mapper: TokenDetailsMapper(
                    amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                    rateConverter: RateConverter()
                ),
                configuration: keeperCoreMainAssembly.configurationAssembly.configuration
            ),
            tokenDetailsListContentViewController: historyListModule.view,
            chartViewControllerProvider: { [keeperCoreMainAssembly, coreAssembly] in
                ChartAssembly.module(
                    token: .ton(.ton),
                    coreAssembly: coreAssembly,
                    keeperCoreMainAssembly: keeperCoreMainAssembly
                ).view
            }
        )

        module.output.didTapReceive = { [weak self] token in
            self?.openReceive(tokens: [token], wallet: wallet)
        }

        module.output.didTapSend = { [weak self] token in
            let sendItem: SendV3Item = {
                switch token {
                case let .ton(tonToken):
                    return .ton(TonSendData.Item.token(tonToken, amount: 0))
                case .tron:
                    return .tron(TronSendData.Item.usdt(amount: 0))
                }
            }()

            self?.openSend(
                wallet: wallet,
                sendInput: .direct(item: sendItem),
                sendSource: .jettonScreen,
                comment: nil
            )
        }

        module.output.didTapBuyOrSell = { [weak self] in
            self?.openBuy(wallet: wallet)
        }

        module.output.didTapSwap = { [weak self] token in
            self?.openSwap(wallet: wallet, token: token)
        }

        module.output.didOpenURL = { [weak self] url in
            self?.openURL(url, title: nil)
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openJettonDetails(jettonItem: JettonItem, wallet: Wallet, hasPrice: Bool) {
        guard let navigationController = router.rootViewController.navigationController else { return }

        let historyListModule = HistoryModule(
            dependencies: HistoryModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createJettonHistoryListModule(jettonMasterAddress: jettonItem.jettonInfo.address, wallet: wallet)

        historyListModule.output.didSelectEvent = { [weak self] event in
            switch event {
            case let .tonEvent(event):
                self?.openHistoryEventDetails(wallet: wallet, event: event, network: wallet.network)
            case let .tronEvent(event):
                self?.openTronEventDetails(wallet: wallet, event: event, network: wallet.network)
            }
        }

        let module = TokenDetailsAssembly.module(
            wallet: wallet,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            configurator: JettonTokenDetailsConfigurator(
                wallet: wallet,
                jettonItem: jettonItem,
                mapper: TokenDetailsMapper(
                    amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                    rateConverter: RateConverter()
                ),
                configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
                onShowUnverifiedTokenInfo: { [weak self] in
                    self?.openUnverifiedTokenInfoPopup()
                }
            ),
            tokenDetailsListContentViewController: historyListModule.view,
            chartViewControllerProvider: { [keeperCoreMainAssembly, coreAssembly] in
                guard hasPrice else { return nil }
                return ChartAssembly.module(
                    token: .ton(.jetton(jettonItem)),
                    coreAssembly: coreAssembly,
                    keeperCoreMainAssembly: keeperCoreMainAssembly
                ).view
            }
        )

        module.output.didTapReceive = { [weak self] token in
            self?.openReceive(tokens: [token], wallet: wallet)
        }

        module.output.didTapSend = { [weak self] token in
            let sendItem: SendV3Item = {
                switch token {
                case let .ton(tonToken):
                    return .ton(TonSendData.Item.token(tonToken, amount: 0))
                case .tron:
                    return .tron(TronSendData.Item.usdt(amount: 0))
                }
            }()

            self?.openSend(
                wallet: wallet,
                sendInput: .direct(item: sendItem),
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

    func openTronUSDTDetails(wallet: Wallet) {
        guard let navigationController = router.rootViewController.navigationController else { return }
        Task {
            await keeperCoreMainAssembly.servicesAssembly.tronUSDTFeesService.refresh(wallet: wallet)
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
                self?.openHistoryEventDetails(wallet: wallet, event: event, network: wallet.network)
            case let .tronEvent(event):
                self?.openTronEventDetails(wallet: wallet, event: event, network: wallet.network)
            }
        }

        let configuration = TronUSDTTokenDetailsConfigurator(
            wallet: wallet,
            mapper: TokenDetailsMapper(
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                rateConverter: RateConverter()
            ),
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            feesSnapshotService: keeperCoreMainAssembly.servicesAssembly.tronUSDTFeesService,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            buySellMethodsService: keeperCoreMainAssembly.buySellAssembly.buySellMethodsService()
        )

        configuration.didTapBanner = { [weak self] snapshot in
            if snapshot.isTRXOnlyRegion {
                self?.openReceive(tokens: [.tron(.trx)], wallet: wallet)
            } else {
                self?.openUsdtFees(wallet: wallet, snapshot: snapshot, reason: .topup)
            }
        }
        configuration.didTapTransfersAvailable = { [weak self] snapshot in
            self?.openUsdtFees(wallet: wallet, snapshot: snapshot, reason: .topup)
        }

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
                    coreAssembly: coreAssembly,
                    keeperCoreMainAssembly: keeperCoreMainAssembly
                ).view
            }
        )

        module.output.didTapReceive = { [weak self] token in
            self?.openReceive(tokens: [token], wallet: wallet)
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
                                    self?.openReceive(tokens: [.tron(.trx)], wallet: wallet)
                                }
                            }
                        )
                    )
                } else {
                    return openUsdtFees(wallet: wallet, snapshot: feesSnapshot, reason: .insufficient)
                }
            }

            let sendItem: SendV3Item = {
                switch token {
                case let .ton(tonToken):
                    return .ton(TonSendData.Item.token(tonToken, amount: 0))
                case .tron:
                    return .tron(TronSendData.Item.usdt(amount: 0))
                }
            }()

            openSend(
                wallet: wallet,
                sendInput: .direct(item: sendItem),
                sendSource: .jettonScreen,
                comment: nil
            )
        }

        module.output.didTapBuyOrSell = { [weak self] in
            self?.openBuy(wallet: wallet)
        }

        module.output.didTapSwap = { [weak self] token in
            self?.openSwap(wallet: wallet, token: token)
        }

        module.output.didOpenURL = { [weak self] url in
            self?.openURL(url, title: nil)
        }

        navigationController.pushViewController(module.view, animated: true)
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
            self?.openBattery(wallet: wallet, keepCurrentModal: true)
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
                self?.openHistoryEventDetails(wallet: wallet, event: event, network: wallet.network)
            case let .tronEvent(event):
                self?.openTronEventDetails(wallet: wallet, event: event, network: wallet.network)
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
            self?.openDapp(title: title, url: url, isSilentConnect: true)
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
            self?.openReceive(tokens: [token], wallet: wallet)
        }

        module.output.didTapSend = { [weak self] token in
            let sendItem: SendV3Item = {
                switch token {
                case let .ton(tonToken):
                    return .ton(TonSendData.Item.token(tonToken, amount: 0))
                case .tron:
                    return .tron(TronSendData.Item.usdt(amount: 0))
                }
            }()

            self?.openSend(
                wallet: wallet,
                sendInput: .direct(item: sendItem),
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
            self?.openDapp(title: title, url: url)
        }

        module.output.openJettonDetails = { [weak self] wallet, jettonItem in
            self?.openJettonDetails(jettonItem: jettonItem, wallet: wallet, hasPrice: true)
        }

        module.output.didTapStake = { [weak self] wallet, stakingPoolInfo in
            self?.openStake(wallet: wallet, stakingPoolInfo: stakingPoolInfo)
        }

        module.output.didTapUnstake = { [weak self] wallet, stakingPoolInfo in
            self?.openUnstake(wallet: wallet, stakingPoolInfo: stakingPoolInfo)
        }

        module.output.didTapCollect = { [weak self] in
            self?.openStakingCollect(wallet: $0, stakingPoolInfo: $1, accountStackingInfo: $2)
        }

        module.view.setupBackButton()

        navigationController.pushViewController(module.view, animated: true)
    }

    func openStakingItemDetails(
        wallet: Wallet,
        stakingPoolInfo: StackingPoolInfo
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
            self?.openStake(wallet: wallet, stakingPoolInfo: stakingPoolInfo)
        }

        module.output.didTapUnstake = { [weak self] wallet, stakingPoolInfo in
            self?.openUnstake(wallet: wallet, stakingPoolInfo: stakingPoolInfo)
        }

        module.output.didTapCollect = { [weak self] in
            self?.openStakingCollect(wallet: $0, stakingPoolInfo: $1, accountStackingInfo: $2)
        }

        module.view.setupBackButton()

        navigationController.pushViewController(module.view, animated: true)
    }

    func openStakingCollect(
        wallet: Wallet,
        stakingPoolInfo: StackingPoolInfo,
        accountStackingInfo: AccountStackingInfo
    ) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = StakingConfirmationCoordinator(
            wallet: wallet,
            item: StakingConfirmationItem(
                operation: .withdraw(stakingPoolInfo),
                amount: BigUInt(accountStackingInfo.readyWithdraw)
            ),
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
        let viewController = TKBridgeWebViewController(
            initialURL: url,
            initialTitle: nil,
            jsInjection: nil,
            configuration: .default,
            deeplinkHandler: { url in
                let deeplinkParser = DeeplinkParser()
                let deeplink = try deeplinkParser.parse(string: url)
                _ = self.handleDeeplink(deeplink: deeplink, fromStories: false)
            }
        )
        router.present(viewController)
    }

    func openInAppURL(url: URL) {
        let viewController = SFSafariViewController(url: url)
        router.present(viewController)
    }

    func openBuySellItemURL(_ url: URL, fromViewController: UIViewController) {
        let deeplinkHandler = TKWebViewControllerNavigationHandler { [weak self] deeplink in
            _ = self?.handleDeeplink(deeplink: deeplink, fromStories: false)
        }

        let webViewController = TKWebViewController(url: url, handler: deeplinkHandler)
        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.modalPresentationStyle = .fullScreen
        navigationController.configureTransparentAppearance()
        fromViewController.present(navigationController, animated: true)
    }

    func openStake(wallet: Wallet, stakingPoolInfo: StackingPoolInfo) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = StakingStakeCoordinator(
            wallet: wallet,
            stakingPoolInfo: stakingPoolInfo,
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

        self.router.dismiss(animated: true) { [weak self] in
            self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
            })
        }
    }

    func openUnstake(wallet: Wallet, stakingPoolInfo: StackingPoolInfo) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = StakingUnstakeCoordinator(
            wallet: wallet,
            stakingPoolInfo: stakingPoolInfo,
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

    func openRamp(flow: RampFlow, tokens: [Token], wallet: Wallet) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
        let rampRouter = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = RampCoordinator(
            flow: flow,
            router: rampRouter,
            tokens: tokens,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        coordinator.didTapReceive = { [weak self] tokens, wallet in
            self?.openReceive(tokens: tokens, wallet: wallet) { [weak self] in
                guard let self else { return }
                switch flow {
                case .deposit:
                    coreAssembly.analyticsProvider.log(
                        DepositViewReceiveTokens(from: .walletScreen)
                    )
                case .withdraw:
                    break
                }
            }
        }

        coordinator.didTapSend = { [weak self] wallet, token in
            self?.openSend(
                wallet: wallet,
                sendInput: .direct(item: .ton(.token(token, amount: 0))),
                sendSource: .walletScreen,
                comment: nil
            )
        }

        coordinator.didTapOpenSendFromWithdraw = { [weak self] wallet, sendInput in
            self?.openSendPushedOnto(
                wallet: wallet,
                sendInput: sendInput,
                sendSource: .walletScreen,
                comment: nil,
                pushRouter: rampRouter
            )
        }

        coordinator.didTapOpenMerchant = { [weak self, weak navigationController] url in
            guard let self, let navigationController else { return }
            self.openBuySellItemURL(url, fromViewController: navigationController)
        }

        coordinator.didClose = { [weak self, weak coordinator] in
            self?.router.dismiss()
            self?.removeChild(coordinator)
        }

        coordinator.didRequestTRC20Enable = { [weak self] wallet, enableCompletion in
            self?.openReceiveTRC20Popup(wallet: wallet, enableCompletion: enableCompletion)
        }

        addChild(coordinator)
        coordinator.start()

        router.dismiss(animated: true) { [weak self] in
            self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
            })
        }
    }

    func openReceive(tokens: [Token], wallet: Wallet, completion: (() -> Void)? = nil) {
        let module = ReceiveAssembly.module(
            tokens: tokens,
            wallet: wallet,
            keeperCoreAssembly: keeperCoreMainAssembly
        )

        module.output.didSelectInactiveTRC20 = { [weak self] in
            self?.openReceiveTRC20Popup(
                wallet: $0,
                enableCompletion: {
                    module.input.selectToken(token: .tron(.usdt))
                }
            )
        }

        let navigationController = TKNavigationController(rootViewController: module.view)
        navigationController.setNavigationBarHidden(true, animated: false)

        router.rootViewController.topPresentedViewController().present(
            navigationController,
            animated: true,
            completion: completion
        )
    }

    func openStake(wallet: Wallet) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = StakingCoordinator(
            wallet: wallet,
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

        self.router.dismiss(animated: true) { [weak self] in
            self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
            })
        }
    }

    func openBuy(wallet: Wallet, isInternalPurchasing: Bool) {
        if isInternalPurchasing {
            openBuy(wallet: wallet)
        } else {
            openBrowserDefiFlow()
        }
    }

    func presentStory(story: KeeperCore.Story, shouldDismissCurrentOnAction: Bool = false) {
        let fromViewController = self.router.rootViewController

        mainCoordinatorStoriesController?.presentStory(
            story: .init(id: story.story_id, story: story),
            fromViewController: fromViewController,
            fromAnalyticsProperty: "updates",
            shouldDismissCurrentOnAction: shouldDismissCurrentOnAction
        )
    }

    func openAllUpdates() {
        let module = AllUpdatesAssembly.module(
            storiesStore: keeperCoreMainAssembly.storesAssembly.storiesStore
        )

        module.output.didSelectStory = { [weak self] story in
            self?.presentStory(story: story, shouldDismissCurrentOnAction: true)
        }

        let navigationController = TKNavigationController(rootViewController: module.view)
        navigationController.setNavigationBarHidden(true, animated: false)

        router.present(navigationController, onDismiss: nil)
    }

    func openBuy(wallet: Wallet) {
        let coordinator = BuyCoordinator(
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: ViewControllerRouter(rootViewController: self.router.rootViewController)
        )

        coordinator.didOpenItem = { [weak self] url, fromViewController in
            self?.openBuySellItemURL(url, fromViewController: fromViewController)
        }

        coordinator.didClose = { [weak coordinator, weak self] in
            self?.removeChild(coordinator)
        }

        self.router.dismiss(animated: true) { [weak self] in
            self?.addChild(coordinator)
            coordinator.start()
        }
    }

    func openHistoryEventDetails(wallet: Wallet, event: AccountEventDetailsEvent, network: Network) {
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
            self?.openDapp(title: title, url: url)
        }

        router.rootViewController.dismiss(animated: true) { [weak self] in
            guard let router = self?.router else { return }
            bottomSheetViewController.present(fromViewController: router.rootViewController)
        }
    }

    func openTronEventDetails(wallet: Wallet, event: TronTransaction, network: Network) {
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
            self?.openDapp(title: title, url: url)
        }

        router.rootViewController.dismiss(animated: true) { [weak self] in
            guard let router = self?.router else { return }
            bottomSheetViewController.present(fromViewController: router.rootViewController)
        }
    }

    func openBackup(wallet: Wallet) {
        guard let navigationController = router.rootViewController.navigationController else { return }
        let configuration = SettingsListBackupConfigurator(
            wallet: wallet,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        configuration.didTapBackupManually = { [weak self] in
            self?.openManuallyBackup(wallet: wallet)
        }

        configuration.didTapShowRecoveryPhrase = { [weak self] in
            self?.openRecoveryPhrase(wallet: wallet)
        }

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()

        navigationController.pushViewController(module.viewController, animated: true)
    }

    func openBattery(
        wallet: Wallet,
        jettonMasterAddress: Address? = nil,
        keepCurrentModal: Bool = false
    ) {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = BatteryRefillCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet,
            jettonMasterAddress: jettonMasterAddress,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didOpenRefundURL = { [weak self] url, title in
            self?.openDapp(title: title, url: url)
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
            self.router.dismiss(animated: true) { [weak self] in
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

    func openReceiveTRC20Popup(
        wallet: Wallet,
        enableCompletion: (() -> Void)? = nil
    ) {
        let module = ReceiveTRC20PopupAssembly.module(
            wallet: wallet,
            keeperCoreAssembly: keeperCoreMainAssembly,
            passcodeProvider: getPasscode
        )
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
        bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())

        module.output.didFinish = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        module.output.didEnable = {
            enableCompletion?()
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

    func openManuallyBackup(wallet: Wallet) {
        guard let navigationController = router.rootViewController.navigationController else { return }
        let coordinator = BackupModule(
            dependencies: BackupModule.Dependencies(
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )
        ).createBackupCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet
        )

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
        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
        let configurationBuilder = InfoPopupBottomSheetConfigurationBuilder(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        let content = [
            TKLocales.Token.UnverifiedPopup.lowLiquidity,
            TKLocales.Token.UnverifiedPopup.notListed,
            TKLocales.Token.UnverifiedPopup.usedForSpam,
            TKLocales.Token.UnverifiedPopup.usedForScam,
        ]

        var okButton = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        okButton.content = .init(title: .plainString(TKLocales.Actions.ok))
        okButton.action = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        viewController.configuration = configurationBuilder.commonConfiguration(
            title: TKLocales.Token.unverified,
            caption: TKLocales.Token.UnverifiedPopup.caption,
            body: [.textWithTabs(content: content)],
            buttons: [okButton]
        )

        bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
    }

    func openDapp(title: String?, url: URL, isSilentConnect: Bool = false) {
        let dapp = Dapp(
            name: title ?? "",
            description: "",
            icon: nil,
            poster: nil,
            url: url,
            textColor: nil,
            excludeCountries: nil,
            includeCountries: nil
        )

        let controllerRouter = ViewControllerRouter(rootViewController: router.rootViewController)
        let coordinator = DappCoordinator(
            router: controllerRouter,
            dapp: dapp,
            isSilentConnect: isSilentConnect,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didHandleDeeplink = { [weak self] deeplink in
            _ = self?.handleTonkeeperDeeplink(deeplink, fromStories: false, sendSource: .deepLink)
        }

        addChild(coordinator)
        coordinator.start()
    }

    private func openHistoryTab() {
        guard let historyViewController = historyCoordinator?.router.rootViewController else { return }
        guard let index = router.rootViewController.viewControllers?.firstIndex(of: historyViewController) else { return }
        router.rootViewController.navigationController?.popToRootViewController(animated: true)
        router.rootViewController.selectedIndex = index
        router.dismiss(animated: true)
    }

    private func openBrowserTab() {
        guard let browserViewController = browserCoordinator?.router.rootViewController else { return }
        guard let index = router.rootViewController.viewControllers?.firstIndex(of: browserViewController) else { return }
        router.rootViewController.navigationController?.popToRootViewController(animated: true)
        router.rootViewController.selectedIndex = index
        router.dismiss(animated: true)
    }

    private func openBrowserTabExplore() {
        openBrowserTab()
        browserCoordinator?.openExplore()
    }

    private func openBrowserDefiFlow() {
        openBrowserTab()
        browserCoordinator?.openDefi()
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

    private func getPasscode() async -> String? {
        return await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
        )
    }

    private func didOpenAppWithPushNotificationTapHandler(userInfo: [AnyHashable: Any]?) {
        coreAssembly.analyticsProvider.log(eventKey: .pushClick)

        if let link = userInfo?["link"] as? String,
           let linkURL = URL(string: link)
        {
            openURL(linkURL, title: nil)
            return
        }

        if let dappUrl = userInfo?["dapp_url"] as? String,
           let dappUrlURL = URL(string: dappUrl)
        {
            openURL(dappUrlURL, title: nil)
            return
        }

        if let deeplink = userInfo?["deeplink"] as? String {
            _ = self.handleDeeplink(deeplink: deeplink, fromStories: false)
            return
        }
    }
}

// MARK: - Ton Connect

// MARK: - AppStateTrackerObserver

extension MainCoordinator: AppStateTrackerObserver {
    func didUpdateState(_ state: TKCore.AppStateTracker.State) {
        switch (appStateTracker.state, reachabilityTracker.state) {
        case (.active, .connected):
            mainController.startUpdates()
        case (.background, _):
            mainController.stopUpdates()
        default: return
        }
    }
}

// MARK: - ReachabilityTrackerObserver

extension MainCoordinator: ReachabilityTrackerObserver {
    func didUpdateState(_ state: TKCore.ReachabilityTracker.State) {
        switch reachabilityTracker.state {
        case .connected:
            mainController.startUpdates()
        default:
            return
        }
    }
}
