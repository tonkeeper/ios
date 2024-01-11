import TKUIKit
import TKCoordinator

public struct MainModule {
  public init() {}
  
  public func createMainCoordinator() -> MainCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let tabBarController = TKTabBarController()
    tabBarController.configureAppearance()
    
    let coordinator = MainCoordinator(router: TabBarControllerRouter(rootViewController: tabBarController))
    return coordinator
  }
}
