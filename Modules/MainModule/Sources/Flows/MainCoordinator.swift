import UIKit
import TKCoordinator
import TKUIKit
import WalletModule
import HistoryModule
import CollectiblesModule

public final class MainCoordinator: RouterCoordinator<TabBarControllerRouter> {
  
  let walletCoordinator = WalletModule().createWalletCoordinator()
  let historyCoordinator = HistoryModule().createHistoryCoordinator()
  let collectiblesCoordinator = CollectiblesModule().createCollectiblesCoordinator()

  public override func start() {
    setupChildCoordinators()
  }
}

private extension MainCoordinator {
  func setupChildCoordinators() {
    
    let coordinators = [walletCoordinator,
                        historyCoordinator,
                        collectiblesCoordinator]
    let viewControllers = coordinators.map { $0.router.rootViewController }
    coordinators.forEach {
      addChild($0)
      $0.start()
    }
    
    router.set(viewControllers: viewControllers, animated: false)
  }
}
