import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

public final class CollectiblesCoordinator: RouterCoordinator<NavigationControllerRouter> {
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: NavigationControllerRouter,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
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
    let module = CollectiblesAssembly.module(
      collectiblesController: keeperCoreMainAssembly.collectiblesController()) { [keeperCoreMainAssembly] wallet in
        CollectiblesListAssembly.module(
          collectiblesListController: keeperCoreMainAssembly.collectiblesListController(wallet: wallet)
        )
      }
    
    router.push(viewController: module.view, animated: false)
  }
}
