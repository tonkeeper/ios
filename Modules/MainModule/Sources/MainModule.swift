import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

public struct MainModule {
  private let dependencies: Dependencies
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  public func createMainCoordinator() -> MainCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let tabBarController = TKTabBarController()
    tabBarController.configureAppearance()
    
    let coordinator = MainCoordinator(
      router: TabBarControllerRouter(rootViewController: tabBarController),
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
    )
    return coordinator
  }
}

public extension MainModule {
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
