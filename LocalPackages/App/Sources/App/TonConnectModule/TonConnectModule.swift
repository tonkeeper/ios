import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct TonConnectModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createConnectCoordinator(router: ViewControllerRouter,
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
  
  func createConfirmationCoordinator(
    window: UIWindow,
    wallet: Wallet,
    appRequest: TonConnect.AppRequest,
    app: TonConnectApp
  ) -> TonConnectConfirmationCoordinator {
    TonConnectConfirmationCoordinator(
      router: WindowRouter(window: window),
      tonConnectConfirmationController: dependencies.keeperCoreMainAssembly.tonConnectAssembly.tonConnectConfirmationController(
        wallet: wallet,
        appRequest: appRequest,
        app: app
      ),
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      coreAssembly: dependencies.coreAssembly
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
