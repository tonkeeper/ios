import UIKit
import TKUIKit
import TKCoordinator

public final class AppCoordinator: RouterCoordinator<WindowRouter> {
  
  public override func start() {
    openRoot()
  }
}

private extension AppCoordinator {
  func openRoot() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let rootCoordinator = RootCoordinator(router: NavigationControllerRouter(rootViewController: navigationController))
    self.router.window.rootViewController = rootCoordinator.router.rootViewController
    
    addChild(rootCoordinator)
    rootCoordinator.start()
  }
}
