import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct SendModule {
  private let dependencies: Dependencies
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  public func createSendTokenCoordinator(router: NavigationControllerRouter,
                                         sendItem: SendItem) -> SendTokenCoordinator {
    let coordinator = SendTokenCoordinator(
      router: router,
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      sendItem: sendItem
    )
    return coordinator
  }
}

extension SendModule {
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
