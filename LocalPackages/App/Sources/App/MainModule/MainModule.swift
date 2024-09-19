import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct MainModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createMainCoordinator() -> MainCoordinator {
    let tabBarController = TKTabBarController()
    tabBarController.configureAppearance()
    
    let coordinator = MainCoordinator(
      router: TabBarControllerRouter(rootViewController: tabBarController),
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      appStateTracker: dependencies.coreAssembly.appStateTracker,
      reachabilityTracker: dependencies.coreAssembly.reachabilityTracker,
      recipientResolver: dependencies.keeperCoreMainAssembly.loadersAssembly.recipientResolver(),
      jettonBalanceResolver: dependencies.keeperCoreMainAssembly.loadersAssembly.jettonBalanceResolver()
      
    )
    return coordinator
  }
}

extension MainModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    
    public init(coreAssembly: TKCore.CoreAssembly,
                keeperCoreMainAssembly: KeeperCore.MainAssembly) {
      self.coreAssembly = coreAssembly
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
    }
  }
}
