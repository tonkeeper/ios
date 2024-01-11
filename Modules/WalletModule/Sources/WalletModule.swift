import TKUIKit
import TKCoordinator

public struct WalletModule {
  public init() {}
  
  public func createWalletCoordinator() -> WalletCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = WalletCoordinator(router: NavigationControllerRouter(rootViewController: navigationController))
    return coordinator
  }
}
