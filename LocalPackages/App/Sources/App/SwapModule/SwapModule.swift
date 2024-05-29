import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct SwapModule {
  private let dependencies: Dependencies
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  public func createSwapTokenCoordinator(router: NavigationControllerRouter,
                                         sellItem: SwapItem,
                                         buyItem: SwapItem? = nil) -> SwapTokensCoordinator {
    let coordinator = SwapTokensCoordinator(
      router: router,
      walletAssembly: dependencies.keeperCoreMainAssembly.walletAssembly,
      mainAssembly: dependencies.keeperCoreMainAssembly,
      sellItem: sellItem,
      buyItem: buyItem
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

