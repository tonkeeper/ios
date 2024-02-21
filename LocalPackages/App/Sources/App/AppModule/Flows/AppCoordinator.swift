import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

public final class AppCoordinator: RouterCoordinator<WindowRouter> {
  
  let coreAssembly: TKCore.CoreAssembly
  let keeperCoreAssembly: KeeperCore.Assembly
  
  private weak var rootCoordinator: RootCoordinator?
  
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
  
  public override func start(deeplink: CoordinatorDeeplink? = nil) {
    openRoot(deeplink: deeplink)
  }
  
  public override func handleDeeplink(deeplink: CoordinatorDeeplink?) {
    rootCoordinator?.handleDeeplink(deeplink: deeplink)
  }
}

private extension AppCoordinator {
  func openRoot(deeplink: TKCoordinator.CoordinatorDeeplink? = nil) {
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
    
    self.rootCoordinator = rootCoordinator
    
    addChild(rootCoordinator)
    rootCoordinator.start(deeplink: deeplink)
  }
}
