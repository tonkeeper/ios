import TKUIKit
import TKCoordinator

public struct CollectiblesModule {
  public init() {}
  
  public func createCollectiblesCoordinator() -> CollectiblesCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = CollectiblesCoordinator(router: NavigationControllerRouter(rootViewController: navigationController))
    return coordinator
  }
}
