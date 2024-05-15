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
  
  private let walletModule: WalletModule
  private let historyModule: HistoryModule
  private let collectiblesModule: CollectiblesModule
  
  private var walletCoordinator: WalletCoordinator?
  private var historyCoordinator: HistoryCoordinator?
  private var collectiblesCoordinator: CollectiblesCoordinator?
  
  private weak var addWalletCoordinator: AddWalletCoordinator?
  private weak var sendTokenCoordinator: SendTokenCoordinator?
  private weak var stakeCoordinator: StakeCoordinator?
  
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
    self.collectiblesModule = CollectiblesModule(
      dependencies: CollectiblesModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    )
    self.appStateTracker = appStateTracker
    self.reachabilityTracker = reachabilityTracker
    
    super.init(router: router)
    
    mainController.didReceiveTonConnectRequest = { [weak self] request, wallet, app in
      self?.handleTonConnectRequest(request, wallet: wallet, app: app)
    }
    
    appStateTracker.addObserver(self)
    reachabilityTracker.addObserver(self)
  }
  
  override func start(deeplink: CoordinatorDeeplink? = nil) {
    didSendTransactionToken = NotificationCenter.default.addObserver(
      forName: NSNotification.Name(
        "DID SEND TRANSACTION"
      ),
      object: nil,
      queue: .main) { [weak self] _ in
        self?.router.rootViewController.selectedIndex = 1
      }
    setupTabBarTaps()
    setupChildCoordinators()
    Task {
      await mainController.start()
      await MainActor.run {
        _ = handleDeeplink(deeplink: deeplink)
      }
    }
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
      
    walletCoordinator.didTapStake = { [weak self] wallet in
      self?.openStake(wallet: wallet)
    }
    
    let historyCoordinator = historyModule.createHistoryCoordinator()
    
    let collectiblesCoordinator = collectiblesModule.createCollectiblesCoordinator()

    self.walletCoordinator = walletCoordinator
    self.historyCoordinator = historyCoordinator
    self.collectiblesCoordinator = collectiblesCoordinator

    let coordinators = [
      walletCoordinator,
      historyCoordinator,
      collectiblesCoordinator
    ].compactMap { $0 }
    let viewControllers = coordinators.compactMap { $0.router.rootViewController }
    coordinators.forEach {
      addChild($0)
      $0.start()
    }
    
    router.set(viewControllers: viewControllers, animated: false)
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
    
    self.router.present(navigationController, onDismiss: { [weak self] in
      self?.sendTokenCoordinator = nil
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
    
    func openStake(wallet: Wallet) {
        let navigationController = TKNavigationController()
        navigationController.configureDefaultAppearance()
        
        let stakeCoordinator = StakeModule(
            dependencies: StakeModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createStakeCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet
        )
        
        stakeCoordinator.didFinish = { [weak self, weak stakeCoordinator, weak navigationController] in
          self?.stakeCoordinator = nil
          navigationController?.dismiss(animated: true)
          guard let stakeCoordinator else { return }
          self?.removeChild(stakeCoordinator)
        }
        
        self.stakeCoordinator = stakeCoordinator
        
        addChild(stakeCoordinator)
        stakeCoordinator.start()
        
        self.router.present(navigationController, onDismiss: { [weak self] in
          self?.stakeCoordinator = nil
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
            parameters: parameters,
            manifest: manifest
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
      if let collectiblesCoordinator = collectiblesCoordinator, collectiblesCoordinator.handleTonkeeperDeeplink(deeplink: deeplink) {
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
          coreAssembly: coreAssembly,
          scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
          passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
        )
      ).createPairSignerImportCoordinator(
        publicKey: publicKey,
        name: name,
        passcode: nil,
        router: NavigationControllerRouter(
          rootViewController: navigationController
        )
      )
      
      coordinator.didPrepareForPresent = { [weak router] in
        router?.present(navigationController)
      }
      
      coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
        navigationController?.dismiss(animated: true)
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      }
      
      coordinator.didPaired = { [weak self, weak coordinator, weak navigationController] in 
        navigationController?.dismiss(animated: true)
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      }
      
      addChild(coordinator)
      coordinator.start()
    }
  }
  
  func openWalletPicker() {
    let module = WalletsListAssembly.module(
      walletListController: keeperCoreMainAssembly.walletStoreWalletListController()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didTapAddWalletButton = { [weak self, unowned bottomSheetViewController] in
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
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
        passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
      )
    )
    
    let coordinator = module.createAddWalletCoordinator(options: [.createRegular, .importRegular, .importWatchOnly, .importTestnet, .signer],
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
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
        passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
      )
    )
    
    let module = addWalletModuleModule.createCustomizeWalletModule(
      name: wallet.metaData.label,
      tintColor: wallet.metaData.tintColor,
      emoji: wallet.metaData.emoji,
      configurator: EditWalletCustomizeWalletViewModelConfigurator()
    )
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.updateWallet(wallet: wallet, model: model)
    }
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    
    module.view.setupRightCloseButton { [weak navigationController] in
      navigationController?.dismiss(animated: true)
    }
    
    fromViewController.present(navigationController, animated: true)
  }
  
  func updateWallet(wallet: Wallet, model: CustomizeWalletModel) {
    let controller = keeperCoreMainAssembly.walletUpdateAssembly.walletUpdateController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      emoji: model.emoji)
    do {
      try controller.updateWallet(wallet: wallet, metaData: metaData)
    } catch {
      print("Log: Wallet update failed")
    }
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
