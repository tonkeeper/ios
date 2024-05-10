import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct SwapModule {
  private let dependencies: Dependencies
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  public func createSwapTokenCoordinator(router: NavigationControllerRouter) -> SwapTokenCoordinator {
    let coordinator = SwapTokenCoordinator(
      router: router,
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
    )
    return coordinator
  }
}


extension SwapModule {
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
