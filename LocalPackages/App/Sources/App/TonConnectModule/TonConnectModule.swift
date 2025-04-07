import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

@MainActor
struct TonConnectModule {

  private let dependencies: Dependencies

  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createConnectCoordinator(router: WindowRouter,
                                flow: TonConnectConnectCoordinator.Flow,
                                connector: TonConnectConnectCoordinatorConnector,
                                parameters: TonConnectParameters,
                                manifest: TonConnectManifest,
                                showWalletPicker: Bool) -> TonConnectConnectCoordinator {
    TonConnectConnectCoordinator(
      router: router,
      flow: flow,
      connector: connector,
      parameters: parameters,
      manifest: manifest,
      showWalletPicker: showWalletPicker,
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
