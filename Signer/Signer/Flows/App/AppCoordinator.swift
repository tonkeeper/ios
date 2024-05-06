import UIKit
import TKCoordinator
import SignerCore

final class AppCoordinator: RouterCoordinator<WindowRouter> {
  
  private let signerCoreAssembly: SignerCore.Assembly
  
  private weak var rootCoordinator: RootCoordinator?
  
  init(router: WindowRouter,
       signerCoreAssembly: SignerCore.Assembly) {
    self.signerCoreAssembly = signerCoreAssembly
    super.init(router: router)
  }
  
  override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
    router.window.applyThemeMode(.blue)
    openRoot(deeplink: deeplink)
  }
  
  override func handleDeeplink(deeplink: (any CoordinatorDeeplink)?) -> Bool {
    guard let rootCoordinator else { return false }
    return rootCoordinator.handleDeeplink(deeplink: deeplink)
  }
}

private extension AppCoordinator {
  func openRoot(deeplink: TKCoordinator.CoordinatorDeeplink? = nil) {
    let navigationController = NavigationController()
    let rootCoordinator = RootCoordinator(
      router: .init(rootViewController: navigationController),
      signerCoreAssembly: signerCoreAssembly
    )
    router.window.rootViewController = rootCoordinator.router.rootViewController
    
    self.rootCoordinator = rootCoordinator
    
    addChild(rootCoordinator)
    rootCoordinator.start(deeplink: deeplink)
  }
}
