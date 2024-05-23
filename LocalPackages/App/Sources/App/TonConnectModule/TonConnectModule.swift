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
                                connector: TonConnectConnectCoordinatorConnector,
                                parameters: TonConnectParameters,
                                manifest: TonConnectManifest,
                                showWalletPicker: Bool) -> TonConnectConnectCoordinator {
    TonConnectConnectCoordinator(
      router: router,
      connector: connector,
      parameters: parameters,
      manifest: manifest,
      showWalletPicker: showWalletPicker,
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
    )
  }
  
  func createConfirmationCoordinator(
    window: UIWindow,
    wallet: Wallet,
    appRequest: TonConnect.AppRequest,
    app: TonConnectApp
  ) -> SignTransactionConfirmationCoordinator {
    SignTransactionConfirmationCoordinator(
      router: WindowRouter(window: window),
      wallet: wallet,
      confirmator: DefaultTonConnectSignTransactionConfirmationCoordinatorConfirmator(
        app: app,
        appRequest: appRequest,
        sendService: dependencies.keeperCoreMainAssembly.servicesAssembly.sendService(),
        tonConnectService: dependencies.keeperCoreMainAssembly.tonConnectAssembly.tonConnectService()
      ),
      tonConnectConfirmationController: dependencies.keeperCoreMainAssembly.tonConnectAssembly.tonConnectConfirmationController(
        wallet: wallet,
        signTransactionParams: appRequest.params
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
