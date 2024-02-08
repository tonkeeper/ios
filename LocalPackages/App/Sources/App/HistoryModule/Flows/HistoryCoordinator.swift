import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

public final class HistoryCoordinator: RouterCoordinator<NavigationControllerRouter> {
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
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
    let module = HistoryAssembly.module(
      historyController: keeperCoreMainAssembly.historyController(),
      listModuleProvider: { [keeperCoreMainAssembly] wallet in
        HistoryListAssembly.module(
          historyListController: keeperCoreMainAssembly.historyListController(),
          historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider())
        )
      },
      emptyModuleProvider: { wallet in
        HistoryEmptyAssembly.module()
      }
    )
    
    router.push(viewController: module.view, animated: false)
  }
}
