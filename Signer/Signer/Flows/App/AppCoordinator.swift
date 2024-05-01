import UIKit
import SignerCore

final class AppCoordinator: RouterCoordinator<WindowRouter> {
  
  private let signerCoreAssembly: SignerCore.Assembly
  
  init(router: WindowRouter,
       signerCoreAssembly: SignerCore.Assembly) {
    self.signerCoreAssembly = signerCoreAssembly
    super.init(router: router)
  }
  
  override func start() {
    openRoot()
  }
}

private extension AppCoordinator {
  func openRoot() {
    let navigationController = NavigationController()
    let rootCoordinator = RootCoordinator(
      router: .init(rootViewController: navigationController),
      signerCoreAssembly: signerCoreAssembly
    )
    router.window.rootViewController = rootCoordinator.router.rootViewController
    addChild(rootCoordinator)
    rootCoordinator.start()
  }
}
