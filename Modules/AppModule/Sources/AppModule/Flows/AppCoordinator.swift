import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

public final class AppCoordinator: RouterCoordinator<WindowRouter> {
  
  let coreAssembly: TKCore.CoreAssembly
  let keeperCoreAssembly: KeeperCore.Assembly
  
  public override init(router: WindowRouter) {
    self.coreAssembly = TKCore.CoreAssembly()
    self.keeperCoreAssembly = KeeperCore.Assembly(
      dependencies: Assembly.Dependencies(
        cacheURL: coreAssembly.cacheURL,
        sharedCacheURL: coreAssembly.sharedCacheURL
      )
    )
    super.init(router: router)
  }
  
  public override func start() {
    openRoot()
  }
}

private extension AppCoordinator {
  func openRoot() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let rootCoordinator = RootCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      dependencies: RootCoordinator.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreRootAssembly: keeperCoreAssembly.rootAssembly()
      )
    )
    self.router.window.rootViewController = rootCoordinator.router.rootViewController
    
    addChild(rootCoordinator)
    rootCoordinator.start()
  }
}
