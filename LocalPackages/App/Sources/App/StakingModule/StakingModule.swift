import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct StakingModule {
  private let dependencies: Dependencies
  
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createStakingCoordinator(router: NavigationControllerRouter) -> StakingCoordinator {
    return StakingCoordinator(
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      coreAssembly: dependencies.coreAssembly,
      router: router
    )
  }
}

extension StakingModule {
  struct Dependencies {
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    let coreAssembly: TKCore.CoreAssembly
    
    init(keeperCoreMainAssembly: KeeperCore.MainAssembly, coreAssembly: TKCore.CoreAssembly) {
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
      self.coreAssembly = coreAssembly
    }
  }
}
