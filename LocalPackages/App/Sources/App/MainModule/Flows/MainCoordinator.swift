import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore

public final class MainCoordinator: RouterCoordinator<TabBarControllerRouter> {
  
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  private let mainController: KeeperCore.MainController
  
  private let walletModule: WalletModule
  private let historyModule: HistoryModule
  private let collectiblesModule: CollectiblesModule
  
  private var walletCoordinator: WalletCoordinator?
  private var historyCoordinator: HistoryCoordinator?
  private var collectiblesCoordinator: CollectiblesCoordinator?
  
  init(router: TabBarControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
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
  }
  
  public override func start() {
    setupChildCoordinators()
    mainController.loadNftsState()
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
