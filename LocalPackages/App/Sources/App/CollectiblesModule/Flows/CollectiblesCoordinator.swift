import UIKit
import TKCoordinator
import TKUIKit

public final class CollectiblesCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public override init(router: NavigationControllerRouter) {
    super.init(router: router)
    router.rootViewController.tabBarItem.title = "Collectibles"
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.purchase
  }
  
  public override func start() {
    openCollectibles()
  }
}

private extension CollectiblesCoordinator {
  func openCollectibles() {
    let module = CollectiblesAssembly.module()
    
    router.push(viewController: module.view, animated: false)
  }
}
