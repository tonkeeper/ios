import TKUIKit
import TKCoordinator

public struct HistoryModule {
  public init() {}
  
  public func createHistoryCoordinator() -> HistoryCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = HistoryCoordinator(router: NavigationControllerRouter(rootViewController: navigationController))
    return coordinator
  }
}
