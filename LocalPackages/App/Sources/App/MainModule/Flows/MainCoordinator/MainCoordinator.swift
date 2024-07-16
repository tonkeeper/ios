import UIKit
import TKCoordinator
import TKLocalize
import TKUIKit
import KeeperCore
import TKCore
import TonSwift

final class MainCoordinator: RouterCoordinator<TabBarControllerRouter> {
  
  var didLogout: (() -> Void)?
  
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  private let mainController: KeeperCore.MainController
  
  private let mainCoordinatorStateManager: MainCoordinatorStateManager
  private let walletsStoreUpdater: WalletsStoreUpdater
  
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
  
  private let appStateTracker: AppStateTracker
  private let reachabilityTracker: ReachabilityTracker
  
  private var didSendTransactionToken: NSObjectProtocol?
  
  init(router: TabBarControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       appStateTracker: AppStateTracker,
       reachabilityTracker: ReachabilityTracker) {
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
    
    self.mainCoordinatorStateManager = MainCoordinatorStateManager(walletsStoreV2: keeperCoreMainAssembly.walletAssembly.walletsStoreV2)
    self.walletsStoreUpdater = keeperCoreMainAssembly.walletUpdateAssembly.walletsStoreUpdater
    
    super.init(router: router)
    
    mainController.didReceiveTonConnectRequest = { [weak self] request, wallet, app in
      self?.handleTonConnectRequest(request, wallet: wallet, app: app)
    }
    
    appStateTracker.addObserver(self)
    reachabilityTracker.addObserver(self)
  }
  
  override func start(deeplink: CoordinatorDeeplink? = nil) {
    setupChildCoordinators()
    setupTabBarTaps()
    
    mainCoordinatorStateManager.didUpdateState = { [weak self] state in
      self?.handleStateUpdate(state)
    }
    mainController.start()
    _ = handleDeeplink(deeplink: deeplink)
  }

  override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    if let coreDeeplink = deeplink as? KeeperCore.Deeplink {
      return handleCoreDeeplink(coreDeeplink)
    } else {
      do {
        let deeplink = try mainController.parseDeeplink(deeplink: deeplink?.string)
        return handleCoreDeeplink(deeplink)
      } catch {
        return false
      }
    }
  }
}

private extension MainCoordinator {
  func setupChildCoordinators() {
    let walletCoordinator = walletModule.createWalletCoordinator()
    walletCoordinator.didTapScan = { [weak self] in
      self?.openScan()
    }
    walletCoordinator.didLogout = { [weak self] in
      self?.didLogout?()
    }
    
    walletCoordinator.didTapWalletButton = { [weak self] in
      self?.openWalletPicker()
    }
    
    walletCoordinator.didTapSend = { [weak self] token in
      self?.openSend(token: token)
    }
    
    walletCoordinator.didTapSwap = { [weak self] in
      self?.openSwap()
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
    
    walletCoordinator.didTapBuy = { [weak self] wallet in
      self?.openBuy(wallet: wallet)
    }
    
    walletCoordinator.didTapReceive = { [weak self] token in
      self?.openReceive(token: token)
    }
    
    let historyCoordinator = historyModule.createHistoryCoordinator()
    
    let browserCoordinator = browserModule.createBrowserCoordinator()
    
    let collectiblesCoordinator = collectiblesModule.createCollectiblesCoordinator()
    
    collectiblesCoordinator.didPerformTransaction = { [weak self] in
      self?.router.rootViewController.selectedIndex = 1
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
        _ = self?.handleCoreDeeplink(deeplink)
      })
    }
    
    router.present(navigationController)
  }
  
  func openSend(token: Token, recipient: Recipient? = nil) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    
    let sendTokenCoordinator = SendModule(
      dependencies: SendModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createSendTokenCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      sendItem: .token(token, amount: 0),
      recipient: recipient
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
    
    self.router.present(navigationController, onDismiss: { [weak self, weak sendTokenCoordinator] in
      self?.sendTokenCoordinator = nil
      guard let sendTokenCoordinator else { return }
      self?.removeChild(sendTokenCoordinator)
    })
  }
  
  func openSend(recipient: String, jettonAddress: Address?) {
    ToastPresenter.showToast(configuration: .loading)
    Task {
      guard let resolvedRecipient = await mainController.resolveRecipient(recipient) else {
        await MainActor.run {
          ToastPresenter.hideAll()
          ToastPresenter.showToast(configuration: .failed)
        }
        return
      }
      let token: Token
      if let jettonAddress, let jettonItem = await mainController.resolveJetton(jettonAddress: jettonAddress) {
        token = .jetton(jettonItem)
      } else {
        token = .ton
      }
      
      await MainActor.run {
        ToastPresenter.hideAll()
        self.openSend(token: token, recipient: resolvedRecipient)
      }
    }
  }
  
  func openSwap() {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    navigationController.setNavigationBarHidden(true, animated: false)
    
    let coordinator = WebSwapModule(
      dependencies: WebSwapModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).swapCoordinator(router: NavigationControllerRouter(rootViewController: navigationController))
    
    coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    self.webSwapCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
}

// MARK: - Deeplinks

private extension MainCoordinator {
  func handleCoreDeeplink(_ deeplink: KeeperCore.Deeplink) -> Bool {
    switch deeplink {
    case .ton(let tonDeeplink):
      return handleTonDeeplink(tonDeeplink)
    case .tonConnect(let tonConnectDeeplink):
      return handleTonConnectDeeplink(tonConnectDeeplink)
    case .tonkeeper(let tonkeeperDeeplink):
      return handleTonkeeperDeeplink(tonkeeperDeeplink)
    }
  }
  
  func handleTonDeeplink(_ deeplink: TonDeeplink) -> Bool {
    switch deeplink {
    case .transfer(let recipient, let jettonAddress):
      openSend(recipient: recipient, jettonAddress: jettonAddress)
      return true
    }
  }
  
  func handleTonConnectDeeplink(_ deeplink: TonConnectDeeplink) -> Bool {
    ToastPresenter.hideAll()
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let (parameters, manifest) = try await mainController.handleTonConnectDeeplink(deeplink)
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
  
  func handleTonkeeperDeeplink(_ deeplink: TonkeeperDeeplink) -> Bool {
    switch deeplink {
    case .signer(let signerDeeplink):
      if let addWalletCoordinator, addWalletCoordinator.handleDeeplink(deeplink: deeplink) {
        return true
      }
      router.dismiss(animated: true) { [weak self] in
        self?.handleSignerDeeplink(signerDeeplink)
      }
      return true
    case let .publish(model):
      if let sendTokenCoordinator = sendTokenCoordinator {
        return sendTokenCoordinator.handleTonkeeperPublishDeeplink(model: model)
      }
      if let collectiblesCoordinator = collectiblesCoordinator,
         collectiblesCoordinator.handleTonkeeperDeeplink(deeplink: deeplink) {
        return true
      }
      if let webSwapCoordinator = webSwapCoordinator, 
          webSwapCoordinator.handleTonkeeperPublishDeeplink(model: model) {
        return true
      }
      return false
    }
  }
  
  func handleSignerDeeplink(_ deeplink: TonkeeperDeeplink.SignerDeeplink) {
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
  }
  
  func openWalletPicker() {
    let module = WalletsListAssembly.module(
      model: WalletsPickerListModel(
        walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStoreV2,
        walletsUpdater: keeperCoreMainAssembly.walletUpdateAssembly.walletsStoreUpdater
      ),
      totalBalancesStore: keeperCoreMainAssembly.mainStoresAssembly.walletsTotalBalanceStore,
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
      Task {
        await self.walletsStoreUpdater.updateWalletMetaData(
          wallet,
          metaData: WalletMetaData(
            customizeWalletModel: model
          )
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
      self?.openHistoryEventDetails(event: event)
    }
    
    let module = TokenDetailsAssembly.module(
      wallet: wallet,
      balanceStore: keeperCoreMainAssembly.mainStoresAssembly.convertedBalanceStore,
      configurator: TonTokenDetailsConfigurator(
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
      self?.openReceive(token: token)
    }
    
    module.output.didTapSend = { [weak self] token in
      self?.openSend(token: token)
    }
    
    module.output.didTapBuyOrSell = { [weak self] in
      self?.openBuy(wallet: wallet)
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
    ).createJettonHistoryListModule(jettonItem: jettonItem, wallet: wallet)
    
    historyListModule.output.didSelectEvent = { [weak self] event in
      self?.openHistoryEventDetails(event: event)
    }
    
    let module = TokenDetailsAssembly.module(
      wallet: wallet,
      balanceStore: keeperCoreMainAssembly.mainStoresAssembly.convertedBalanceStore,
      configurator: JettonTokenDetailsConfigurator(jettonItem: jettonItem,
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
      self?.openReceive(token: token)
    }
    
    module.output.didTapSend = { [weak self] token in
      self?.openSend(token: token)
    }
    
    navigationController.pushViewController(module.view, animated: true)
//    router.push(viewController: module.view)
  }
  
  func openReceive(token: Token) {
    let module = ReceiveModule(
      dependencies: ReceiveModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).receiveModule(token: token)
    
    module.view.setupSwipeDownButton()
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureDefaultAppearance()
    
    router.present(navigationController)
  }
  
  func openBuy(wallet: Wallet) {
    let coordinator = BuyCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: ViewControllerRouter(rootViewController: self.router.rootViewController)
    )
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openHistoryEventDetails(event: AccountEventDetailsEvent) {
    let module = HistoryEventDetailsAssembly.module(
      historyEventDetailsController: keeperCoreMainAssembly.historyEventDetailsController(event: event),
      urlOpener: coreAssembly.urlOpener()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    bottomSheetViewController.present(fromViewController: router.rootViewController)
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
      Task { await mainController.startBackgroundUpdate() }
    case (.background, _):
      Task { await mainController.stopBackgroundUpdate() }
    default: return
    }
  }
}

// MARK: - ReachabilityTrackerObserver

extension MainCoordinator: ReachabilityTrackerObserver {
  func didUpdateState(_ state: TKCore.ReachabilityTracker.State) {
    switch reachabilityTracker.state {
    case .connected:
      Task { await mainController.startBackgroundUpdate() }
    default:
      return
    }
  }
}
