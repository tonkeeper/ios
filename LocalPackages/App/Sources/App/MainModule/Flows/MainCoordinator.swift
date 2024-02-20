import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore

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
    
    appStateTracker.addObserver(self)
    reachabilityTracker.addObserver(self)
  }
  
  public override func start() {
    setupChildCoordinators()
    mainController.loadNftsState()
    mainController.startBackgroundUpdate()
  }
}

private extension MainCoordinator {
  func setupChildCoordinators() {
    let walletCoordinator = walletModule.createWalletCoordinator()
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
