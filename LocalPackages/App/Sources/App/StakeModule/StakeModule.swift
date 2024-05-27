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
      coreAssembly: dependencies.coreAssembly,
      router: router
    )
    return coordinator
  }
}

extension StakeModule {
  struct Dependencies {
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    let coreAssembly: TKCore.CoreAssembly
    
    init(keeperCoreMainAssembly: KeeperCore.MainAssembly,
         coreAssembly: TKCore.CoreAssembly) {
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
      self.coreAssembly = coreAssembly
    }
  }
}
