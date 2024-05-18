import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct StakeModule {
  private let dependencies: Dependencies
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  public func createStakeCoordinator(router: NavigationControllerRouter,
                                     wallet: Wallet) -> StakeCoordinator {
    let coordinator = StakeCoordinator(
      router: router,
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      wallet: wallet
    )
    return coordinator
  }
}

extension StakeModule {
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
