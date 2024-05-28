import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct WebSwapModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func swapCoordinator(router: NavigationControllerRouter) -> WebSwapCoordinator {
    let coordinator = WebSwapCoordinator(
      router: router,
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
    )
    
    return coordinator
  }
}

extension WebSwapModule {
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

