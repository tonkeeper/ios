import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct TonConnectModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createConfirmationCoordinator(router: ViewControllerRouter,
                                     parameters: TonConnectParameters,
                                     manifest: TonConnectManifest) -> TonConnectConnectCoordinator {
    TonConnectConnectCoordinator(
      router: router,
      parameters: parameters,
      manifest: manifest,
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
    )
  }
}

extension TonConnectModule {
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
