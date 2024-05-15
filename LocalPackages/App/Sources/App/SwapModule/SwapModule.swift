import TKCoordinator
import TKCore
import KeeperCore

struct SwapModule {
  
  private let dependencies: Dependencies
  
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createSwapCoordinator(router: NavigationControllerRouter, wallet: Wallet) -> SwapCoordinator {
    let coordinator = SwapCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      coreAssembly: dependencies.coreAssembly,
      router: router
    )
    return coordinator
  }
}

extension SwapModule {
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
