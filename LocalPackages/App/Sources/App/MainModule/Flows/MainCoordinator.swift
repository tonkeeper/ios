import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore
import TonSwift

final class MainCoordinator: RouterCoordinator<TabBarControllerRouter> {
  
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  private let mainController: KeeperCore.MainController
  
  private let walletModule: WalletModule
  private let historyModule: HistoryModule
  private let collectiblesModule: CollectiblesModule
  
  private var walletCoordinator: WalletCoordinator?
  private var historyCoordinator: HistoryCoordinator?
  private var collectiblesCoordinator: CollectiblesCoordinator?
  
  private let appStateTracker: AppStateTracker
  private let reachabilityTracker: ReachabilityTracker
  
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
    
    mainController.didUpdateNftsAvailability = { [weak self] isAvailable in
      guard let self = self else { return }
      Task { @MainActor in
        if isAvailable {
          self.showCollectibles()
        } else {
          self.hideCollectibles()
        }
      }
    }
    
    mainController.didReceiveTonConnectRequest = { [weak self] request, wallet, app in
      self?.handleTonConnectRequest(request, wallet: wallet, app: app)
    }
    
    appStateTracker.addObserver(self)
    reachabilityTracker.addObserver(self)
  }
  
  override func start(deeplink: CoordinatorDeeplink? = nil) {
    setupChildCoordinators()
    mainController.loadNftsState()
    mainController.startBackgroundUpdate()
    handleDeeplink(deeplink: deeplink)
  }

  override func handleDeeplink(deeplink: CoordinatorDeeplink?) {
    do {
      let deeplink = try mainController.parseDeeplink(deeplink: deeplink?.string)
      handleCoreDeeplink(deeplink)
    } catch {
      return
    }
  }
}

private extension MainCoordinator {
  func setupChildCoordinators() {
    let walletCoordinator = walletModule.createWalletCoordinator()
    walletCoordinator.didTapScan = { [weak self] in
      self?.openScan()
    }
    
    let historyCoordinator = historyModule.createHistoryCoordinator()
    
    self.walletCoordinator = walletCoordinator
    self.historyCoordinator = historyCoordinator

    let coordinators = [
      walletCoordinator,
      historyCoordinator
    ].compactMap { $0 }
    let viewControllers = coordinators.compactMap { $0.router.rootViewController }
    coordinators.forEach {
      addChild($0)
      $0.start()
    }
    
    router.set(viewControllers: viewControllers, animated: false)
  }
  
  func showCollectibles() {
    guard collectiblesCoordinator == nil else { return }
    let collectiblesCoordinator = collectiblesModule.createCollectiblesCoordinator()
    self.collectiblesCoordinator = collectiblesCoordinator
    addChild(collectiblesCoordinator)
    router.insert(viewController: collectiblesCoordinator.router.rootViewController, at: 2)
    collectiblesCoordinator.start()
  }
  
  func hideCollectibles() {
    guard let collectiblesCoordinator = collectiblesCoordinator else { return }
    removeChild(collectiblesCoordinator)
    self.collectiblesCoordinator = nil
    router.remove(viewController: collectiblesCoordinator.router.rootViewController)
  }
  
  func openScan() {
    let scanModule = ScannerModule(
      dependencies: ScannerModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createScannerModule()
    
    let navigationController = TKNavigationController(rootViewController: scanModule.view)
    navigationController.configureTransparentAppearance()
    
    scanModule.output.didScanDeeplink = { [weak self] deeplink in
      self?.router.dismiss(completion: {
        self?.handleCoreDeeplink(deeplink)
      })
    }
    
    router.present(navigationController)
  }
  
  func openSend(token: Token, recipient: Recipient) {
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
      navigationController?.dismiss(animated: true)
      guard let sendTokenCoordinator else { return }
      self?.removeChild(sendTokenCoordinator)
    }
    
    addChild(sendTokenCoordinator)
    sendTokenCoordinator.start()
    
    self.router.present(navigationController)
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
}

// MARK: - Deeplinks

private extension MainCoordinator {
  func handleCoreDeeplink(_ deeplink: KeeperCore.Deeplink) {
    switch deeplink {
    case .ton(let tonDeeplink):
      handleTonDeeplink(tonDeeplink)
    case .tonConnect(let tonConnectDeeplink):
      handleTonConnectDeeplink(tonConnectDeeplink)
    }
  }
  
  func handleTonDeeplink(_ deeplink: TonDeeplink) {
    switch deeplink {
    case .transfer(let recipient, let jettonAddress):
      openSend(recipient: recipient, jettonAddress: jettonAddress)
    }
  }
  
  func handleTonConnectDeeplink(_ deeplink: TonConnectDeeplink) {
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
  }
}

// MARK: - Ton Connect

private extension MainCoordinator {
  func handleTonConnectRequest(_ request: TonConnect.AppRequest,
                               wallet: Wallet,
                               app: TonConnectApp) {
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
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
      mainController.startBackgroundUpdate()
    case (.background, _):
      mainController.stopBackgroundUpdate()
    default: return
    }
  }
}

// MARK: - ReachabilityTrackerObserver

extension MainCoordinator: ReachabilityTrackerObserver {
  func didUpdateState(_ state: TKCore.ReachabilityTracker.State) {
    switch reachabilityTracker.state {
    case .connected:
      mainController.startBackgroundUpdate()
    default:
      return
    }
  }
}
