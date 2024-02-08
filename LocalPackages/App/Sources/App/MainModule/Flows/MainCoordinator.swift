import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore


public final class MainCoordinator: RouterCoordinator<TabBarControllerRouter> {
  
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
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
    self.collectiblesModule = CollectiblesModule()
    super.init(router: router)
  }
  
  public override func start() {
    setupChildCoordinators()
  }
}

private extension MainCoordinator {
  func setupChildCoordinators() {
    let walletCoordinator = walletModule.createWalletCoordinator()
    let historyCoordinator = historyModule.createHistoryCoordinator()
    let collectiblesCoordinator = collectiblesModule.createCollectiblesCoordinator()
    
    self.walletCoordinator = walletCoordinator
    self.historyCoordinator = historyCoordinator
    self.collectiblesCoordinator = collectiblesCoordinator

    let coordinators = [walletCoordinator,
                        historyCoordinator,
                        collectiblesCoordinator]
    let viewControllers = coordinators.compactMap { $0.router.rootViewController }
    coordinators.forEach {
      addChild($0)
      $0.start()
    }
    
    router.set(viewControllers: viewControllers, animated: false)
  }
}
