import TKCoordinator
import TKCore
import KeeperCore

struct StakeModule {
  
  private let dependencies: Dependencies
  
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createStakeCoordinator(router: NavigationControllerRouter) -> StakeCoordinator {
    let coordinator = StakeCoordinator(
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      router: router
    )
    return coordinator
  }
}

extension StakeModule {
  struct Dependencies {
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    
    init(keeperCoreMainAssembly: KeeperCore.MainAssembly) {
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
    }
  }
}
