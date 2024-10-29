import UIKit
import TKCoordinator
import TKLocalize
import TKUIKit
import TKScreenKit
import KeeperCore
import TKCore
import TonSwift
import BigInt

final class MainCoordinator: RouterCoordinator<TabBarControllerRouter> {
  
  let keeperCoreMainAssembly: KeeperCore.MainAssembly
  let coreAssembly: TKCore.CoreAssembly
  let mainController: KeeperCore.MainController
  
  private let mainCoordinatorStateManager: MainCoordinatorStateManager
  
  private let walletModule: WalletModule
  private let historyModule: HistoryModule
  private let browserModule: BrowserModule
  private let collectiblesModule: CollectiblesModule
  
  private var walletCoordinator: WalletCoordinator?
  private var historyCoordinator: HistoryCoordinator?
  private var browserCoordinator: BrowserCoordinator?
  private var collectiblesCoordinator: CollectiblesCoordinator?
  
  private weak var addWalletCoordinator: AddWalletCoordinator?
  private weak var sendTokenCoordinator: SendTokenCoordinator?
  private weak var webSwapCoordinator: WebSwapCoordinator?
  
  private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
  
  private let appStateTracker: AppStateTracker
  private let reachabilityTracker: ReachabilityTracker
  let recipientResolver: RecipientResolver
  let jettonBalanceResolver: JettonBalanceResolver

  var deeplinkHandleTask: Task<Void, Never>?
  
  private var sendTransactionNotificationToken: NSObjectProtocol?

  private var deeplinkRouter: ContainerViewControllerRouter<UIViewController>?

  init(router: TabBarControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       appStateTracker: AppStateTracker,
       reachabilityTracker: ReachabilityTracker,
       recipientResolver: RecipientResolver,
       jettonBalanceResolver: JettonBalanceResolver) {
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
    self.jettonBalanceResolver = jettonBalanceResolver
    
    self.mainCoordinatorStateManager = MainCoordinatorStateManager(
      walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
      walletNFTsManagedStoreProvider: { wallet in
        keeperCoreMainAssembly.storesAssembly.walletNFTsManagedStore(wallet: wallet)
      }
    )
    
    super.init(router: router)
    
    mainController.didReceiveTonConnectRequest = { [weak self] request, wallet, app in
      self?.handleTonConnectRequest(request, wallet: wallet, app: app)
    }
    
    appStateTracker.addObserver(self)
    reachabilityTracker.addObserver(self)
    
    sendTransactionNotificationToken = NotificationCenter.default
      .addObserver(forName: .transactionSendNotification, object: nil, queue: .main) { [weak self] notification in
        guard let self else { return }
        self.openHistoryTab()
        if let wallet = notification.userInfo?["wallet"] as? Wallet {
          Task {
            await self.keeperCoreMainAssembly.storesAssembly.walletsStore.makeWalletActive(wallet)
          }
        }
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
    DispatchQueue.main.async {
      _ = self.handleDeeplink(deeplink: deeplink)
    }
  }
  
  override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    switch deeplink {
    case let tonkeeperDeeplink as KeeperCore.Deeplink:
      return handleTonkeeperDeeplink(tonkeeperDeeplink)
    case let string as String:
      do {
        let deeplink = try mainController.parseDeeplink(deeplink: string)
        return handleTonkeeperDeeplink(deeplink)
      } catch {
        return false
      }
    default:
      return false
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
      self?.openSend(wallet: wallet, token: token, amount: nil, comment: nil)
    }
    
    walletCoordinator.didTapSwap = { [weak self] wallet in
      self?.openSwap(wallet: wallet)
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
    
    walletCoordinator.didSelectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStackingInfo in
      self?.openStakingItemDetails(
        wallet: wallet,
        stakingPoolInfo: stakingPoolInfo)
    }
    
    walletCoordinator.didSelectCollectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStackingInfo in
      self?.openStakingCollect(
        wallet: wallet,
        stakingPoolInfo: stakingPoolInfo,
        accountStackingInfo: accountStackingInfo)
    }
    
    walletCoordinator.didTapBuy = { [weak self] wallet in
      self?.openBuy(wallet: wallet)
    }
    
    walletCoordinator.didTapReceive = { [weak self] token, wallet in
      self?.openReceive(token: token, wallet: wallet)
    }
    
    walletCoordinator.didTapStake = { [weak self] wallet in
      self?.openStake(wallet: wallet)
    }
    
    walletCoordinator.didTapBackup = { [weak self] wallet in
      self?.openBackup(wallet: wallet)
    }
    
    let historyCoordinator = historyModule.createHistoryCoordinator()
    historyCoordinator.didOpenEventDetails = { [weak self] wallet, event, isTestnet in
      self?.openHistoryEventDetails(wallet: wallet, event: event, isTestnet: isTestnet)
    }
    historyCoordinator.didDecryptComment = { [weak self] wallet, payload, eventId in
      self?.decryptComment(wallet: wallet, payload: payload, eventId: eventId)
    }
    historyCoordinator.didOpenDapp = { url, title in
      self.openDapp(title: title, url: url)
    }
    
    let browserCoordinator = browserModule.createBrowserCoordinator()
    
    let collectiblesCoordinator = collectiblesModule.createCollectiblesCoordinator(parentRouter: router)
    collectiblesCoordinator.didOpenDapp = { url, title in
      self.openDapp(title: title, url: url)
    }
    collectiblesCoordinator.didRequestDeeplinkHandling = { [weak self] deeplink in
      _ = self?.handleTonkeeperDeeplink(deeplink)
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
    let scanModule = ScannerModule(
      dependencies: ScannerModule.Dependencies(
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
      )
    ).createScannerModule(
      configurator: DefaultScannerControllerConfigurator(),
      uiConfiguration: ScannerUIConfiguration(title: TKLocales.Scanner.title,
                                              subtitle: nil,
                                              isFlashlightVisible: true)
    )
    
    let navigationController = TKNavigationController(rootViewController: scanModule.view)
    navigationController.configureTransparentAppearance()
    
    scanModule.output.didScanDeeplink = { [weak self] deeplink in
      self?.router.dismiss(completion: {
        _ = self?.handleTonkeeperDeeplink(deeplink)
      })
    }
    
    router.present(navigationController)
  }
  
  func openSend(wallet: Wallet, token: Token, recipient: Recipient? = nil, amount: BigUInt?, comment: String?) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    
    let sendTokenCoordinator = SendModule(
      dependencies: SendModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createSendTokenCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      wallet: wallet,
      sendItem: .token(token, amount: amount ?? 0),
      recipient: recipient,
      comment: comment
    )
    
    sendTokenCoordinator.didFinish = { [weak self, weak sendTokenCoordinator, weak navigationController] in
      self?.sendTokenCoordinator = nil
      navigationController?.dismiss(animated: true)
      guard let sendTokenCoordinator else { return }
      self?.removeChild(sendTokenCoordinator)
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
  
  func openSwap(wallet: Wallet, token: Token) {
    let fromToken: String?
    let toToken: String?
    switch token {
    case .ton:
      fromToken = TonInfo.symbol
      toToken = nil
    case .jetton(let jetton):
      fromToken = jetton.jettonInfo.symbol
      toToken = TonInfo.symbol
    }
    
    openSwap(wallet: wallet, fromToken: fromToken, toToken: toToken)
  }
  
  func openSwap(wallet: Wallet,
                fromToken: String? = nil,
                toToken: String? = nil) {
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
      guard let coordinator = coordinator else { return }
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

  func handleTonkeeperDeeplink(_ deeplink: KeeperCore.Deeplink) -> Bool {
    switch deeplink {
    case let .transfer(data):
      openSendDeeplink(
        recipient: data.recipient,
        amount: data.amount,
        comment: data.comment,
        jettonAddress: data.jettonAddress,
        expirationTimestamp: data.expirationTimestamp
      )
      return true
    case .buyTon:
      openBuyDeeplink()
      return true
    case .staking:
      openStakingDeeplink()
      return true
    case .pool(let poolAddress):
      openPoolDetailsDeeplink(poolAddress: poolAddress)
      return true
    case .exchange(let provider):
      openExchangeDeeplink(provider: provider)
      return true
    case .swap(let data):
      openSwapDeeplink(fromToken: data.fromToken, toToken: data.toToken)
      return true
    case .action(let eventId):
      openActionDeeplink(eventId: eventId)
      return true
    case .publish(let sign):
      if let sendTokenCoordinator = sendTokenCoordinator {
        return sendTokenCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
      }
      if let collectiblesCoordinator = collectiblesCoordinator,
         collectiblesCoordinator.handleTonkeeperDeeplink(deeplink: deeplink) {
        return true
      }
      if let webSwapCoordinator = webSwapCoordinator,
         webSwapCoordinator.handleTonkeeperPublishDeeplink(sign: sign) {
        return true
      }
      return false
    case .externalSign(let data):
      return handleSignerDeeplink(data)
    case .tonconnect(let parameters):
      return handleTonConnectDeeplink(parameters)
    case .dapp(let dappURL):
      return handleDappDeeplink(url: dappURL)
    }
  }
  
  func handleTonConnectDeeplink(_ parameters: TonConnectParameters) -> Bool {
    ToastPresenter.hideAll()
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let (parameters, manifest) = try await mainController.handleTonConnectDeeplink(parameters)
        await MainActor.run {
          ToastPresenter.hideToast()
          let coordinator = TonConnectModule(
            dependencies: TonConnectModule.Dependencies(
              coreAssembly: coreAssembly,
              keeperCoreMainAssembly: keeperCoreMainAssembly
            )
          ).createConnectCoordinator(
            router: ViewControllerRouter(rootViewController: router.rootViewController),
            connector: DefaultTonConnectConnectCoordinatorConnector(
              tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
            ),
            parameters: parameters,
            manifest: manifest,
            showWalletPicker: true
          )
          
          coordinator.didCancel = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          }
          
          coordinator.didConnect = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          }
          
          addChild(coordinator)
          coordinator.start()
        }
      } catch {
        await MainActor.run {
          ToastPresenter.hideAll()
        }
      }
    }
    return true
  }

  func handleSignerDeeplink(_ deeplink: ExternalSignDeeplink) -> Bool {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    switch deeplink {
    case .link(let publicKey, let name):
      let coordinator = AddWalletModule(
        dependencies: AddWalletModule.Dependencies(
          walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
          storesAssembly: keeperCoreMainAssembly.storesAssembly,
          coreAssembly: coreAssembly,
          scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
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
        self?.router.present(navigationController)
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
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
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
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
      )
    )
    
    let coordinator = module.createAddWalletCoordinator(options: [.createRegular, .importRegular, .signer, .ledger, .importWatchOnly, .importTestnet, ],
                                                        router: router)
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
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
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
  
  
  func openSettings(wallet: Wallet) {
    guard let navigationController = router.rootViewController.navigationController else { return }
    let module = SettingsModule(
      dependencies: SettingsModule.Dependencies(
        keeperCoreMainAssembly: keeperCoreMainAssembly,
        coreAssembly: coreAssembly
      )
    )
    
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
    let coordinator = module.createSettingsCoordinator(router: router,
                                                       wallet: wallet)
    coordinator.didFinish = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
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
      self?.openHistoryEventDetails(wallet: wallet, event: event, isTestnet: wallet.isTestnet)
    }
    
    let module = TokenDetailsAssembly.module(
      wallet: wallet,
      balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      configurator: TonTokenDetailsConfigurator(
        wallet: wallet,
        mapper: TokenDetailsMapper(
          amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
          decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
          rateConverter: RateConverter()
        )
      ),
      tokenDetailsListContentViewController: historyListModule.view,
      chartViewControllerProvider: {[keeperCoreMainAssembly, coreAssembly] in
        ChartAssembly.module(token: .ton,
                             coreAssembly: coreAssembly,
                             keeperCoreMainAssembly: keeperCoreMainAssembly).view
      }
    )
    
    module.output.didTapReceive = { [weak self] token in
      self?.openReceive(token: token, wallet: wallet)
    }
    
    module.output.didTapSend = { [weak self] token in
      self?.openSend(wallet: wallet, token: token, amount: nil, comment: nil)
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
    ).createJettonHistoryListModule(jettonInfo: jettonItem.jettonInfo, wallet: wallet)
    
    historyListModule.output.didSelectEvent = { [weak self] event in
      self?.openHistoryEventDetails(wallet: wallet, event: event, isTestnet: wallet.isTestnet)
    }
    
    let module = TokenDetailsAssembly.module(
      wallet: wallet,
      balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      configurator: JettonTokenDetailsConfigurator(wallet: wallet,
                                                   jettonItem: jettonItem,
                                                   mapper: TokenDetailsMapper(
                                                    amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                                                    decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
                                                    rateConverter: RateConverter()
                                                   )
                                                  ),
      tokenDetailsListContentViewController: historyListModule.view,
      chartViewControllerProvider: {[keeperCoreMainAssembly, coreAssembly] in
        guard hasPrice else { return nil }
        return ChartAssembly.module(token: .jetton(jettonItem),
                                    coreAssembly: coreAssembly,
                                    keeperCoreMainAssembly: keeperCoreMainAssembly).view
      }
    )
    
    module.output.didTapReceive = { [weak self] token in
      self?.openReceive(token: token, wallet: wallet)
    }
    
    module.output.didTapSend = { [weak self] token in
      self?.openSend(wallet: wallet, token: token, recipient: nil, amount: nil, comment: nil)
    }
    
    module.output.didTapSwap = { [weak self] token in
      self?.openSwap(wallet: wallet, token: token)
    }
    
    module.output.didOpenURL = { [weak self] url in
      self?.openURL(url, title: nil)
    }
    
    navigationController.pushViewController(module.view, animated: true)
  }
  
  func openStakingItemDetails(wallet: Wallet,
                              stakingPoolInfo: StackingPoolInfo) {
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
  
  func openStakingCollect(wallet: Wallet,
                          stakingPoolInfo: StackingPoolInfo,
                          accountStackingInfo: AccountStackingInfo) {
    let navigationController = TKNavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    
    let coordinator = StakingConfirmationCoordinator(
      wallet: wallet,
      item: StakingConfirmationItem(operation: .withdraw(stakingPoolInfo), amount: BigUInt(accountStackingInfo.readyWithdraw), isMax: false),
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: NavigationControllerRouter(rootViewController: navigationController)
    )
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
    }
    
    coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start(deeplink: nil)
    
    router.present(navigationController)
  }
  
  func openURL(_ url: URL, title: String?) {
    let viewController = TKBridgeWebViewController(
      initialURL: url,
      initialTitle: nil,
      jsInjection: nil,
      configuration: .default)
    router.present(viewController)
  }
  
  func openBuySellItemURL(_ url: URL, fromViewController: UIViewController) {
    let webViewController = TKWebViewController(url: url)
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
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      self?.router.dismiss()
      self?.removeChild(coordinator)
    }
    
    coordinator.didClose = { [weak self, weak coordinator] in
      self?.router.dismiss()
      self?.removeChild(coordinator)
    }
    
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
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      self?.router.dismiss()
      self?.removeChild(coordinator)
    }
    
    coordinator.didClose = { [weak self, weak coordinator] in
      self?.router.dismiss()
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start(deeplink: nil)
    
    self.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
    })
  }
  
  func openReceive(token: Token, wallet: Wallet) {
    let module = ReceiveModule(
      dependencies: ReceiveModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).receiveModule(token: token, wallet: wallet)
    
    module.view.setupSwipeDownButton()
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureDefaultAppearance()
    
    router.present(navigationController)
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
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      self?.router.dismiss()
      self?.removeChild(coordinator)
    }
    
    coordinator.didClose = { [weak self, weak coordinator] in
      self?.router.dismiss()
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start(deeplink: nil)
    
    self.router.dismiss(animated: true) { [weak self] in
      self?.router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
        self?.removeChild(coordinator)
      })
    }
  }
  
  func openBuy(wallet: Wallet) {
    let coordinator = BuyCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: ViewControllerRouter(rootViewController: self.router.rootViewController)
    )
    
    coordinator.didOpenItem = { url, fromViewController in
      self.openBuySellItemURL(url, fromViewController: fromViewController)
    }
    
    self.router.dismiss(animated: true) { [weak self] in
      self?.addChild(coordinator)
      coordinator.start()
    }
  }
  
  func openHistoryEventDetails(wallet: Wallet, event: AccountEventDetailsEvent, isTestnet: Bool) {
    let module = HistoryEventDetailsAssembly.module(
      wallet: wallet,
      event: event,
      keeperCoreAssembly: keeperCoreMainAssembly,
      urlOpener: coreAssembly.urlOpener(),
      isTestnet: isTestnet
    )
    
    module.output.didSelectEncryptedComment = { [weak self] wallet, payload, eventId in
      self?.decryptComment(wallet: wallet, payload: payload, eventId: eventId)
    }
    
    module.output.didTapOpenTransactionInTonviewer = { [weak self, keeperCoreMainAssembly] in
      guard let url = TonviewerLinkBuilder(configuration: keeperCoreMainAssembly.configurationAssembly.configuration)
        .buildLink(context: .eventDetails(eventID: event.accountEvent.eventId), isTestnet: wallet.isTestnet) else { return }
      self?.openDapp(title: "Tonviewer", url: url)
    }
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
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
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
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
  
  func openRecoveryPhrase(wallet: Wallet) {
    guard let navigationController = router.rootViewController.navigationController else { return }
    let coordinator = SettingsRecoveryPhraseCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: NavigationControllerRouter(rootViewController: navigationController)
    )
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
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
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openInsufficientFundsPopup(jettonInfo: JettonInfo, requiredAmount: BigUInt, availableAmount: BigUInt) {
    let viewController = InsufficientFundsViewController()
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
    
    let configurationBuilder = InsufficientFundsViewControllerConfigurationBuilder(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    let configuration = configurationBuilder.insufficientTokenConfiguration(
      tokenSymbol: jettonInfo.symbol ?? jettonInfo.name,
      tokenFractionalDigits: jettonInfo.fractionDigits,
      required: requiredAmount,
      available: availableAmount,
      okAction: { [weak bottomSheetViewController] in
        bottomSheetViewController?.dismiss()
      }
    )
    viewController.configuration = configuration
    router.dismiss(animated: true) { [router] in
      bottomSheetViewController.present(fromViewController: router.rootViewController)
    }
  }
  
  func openDapp(title: String?, url: URL) {
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
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )

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
  
  private func decryptComment(wallet: Wallet,
                              payload: EncryptedCommentPayload,
                              eventId: String) {
    
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
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
    )
  }
}

// MARK: - Ton Connect

private extension MainCoordinator {
  func handleTonConnectRequest(_ request: TonConnect.AppRequest,
                               wallet: Wallet,
                               app: TonConnectApp) {
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = TKWindow(windowScene: windowScene)
    let coordinator = TonConnectModule(
      dependencies: TonConnectModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createConfirmationCoordinator(window: window, wallet: wallet, appRequest: request, app: app)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didConfirm = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}

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
