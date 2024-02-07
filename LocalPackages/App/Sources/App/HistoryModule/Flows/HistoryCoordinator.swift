import UIKit
import TKCoordinator
import TKUIKit

public final class HistoryCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public override init(router: NavigationControllerRouter) {
    super.init(router: router)
    router.rootViewController.tabBarItem.title = "History"
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.clock
  }
  
  public override func start() {
    openHistory()
  }
}

private extension HistoryCoordinator {
  func openHistory() {
    let module = HistoryAssembly.module()
    
    router.push(viewController: module.view, animated: false)
  }
}
