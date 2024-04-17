import TKCoordinator
import TKCore
import KeeperCore

struct BuyModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createSettingsCoordinator(router: NavigationControllerRouter) -> SettingsCoordinator {
    let coordinator = SettingsCoordinator(
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      coreAssembly: dependencies.coreAssembly,
      router: router
    )
    return coordinator
  }
}

extension BuyModule {
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
