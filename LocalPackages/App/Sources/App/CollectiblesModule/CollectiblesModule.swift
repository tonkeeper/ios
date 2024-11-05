import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

@MainActor
public struct CollectiblesModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  public func createCollectiblesCoordinator(parentRouter: TabBarControllerRouter?) -> CollectiblesCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    navigationController.setNavigationBarHidden(true, animated: false)
    
    let coordinator = CollectiblesCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      parentRouter: parentRouter,
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
    )
    return coordinator
  }
}

extension CollectiblesModule {
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
