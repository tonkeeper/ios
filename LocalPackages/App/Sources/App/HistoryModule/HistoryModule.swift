import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct HistoryModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createHistoryCoordinator() -> HistoryCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    navigationController.setNavigationBarHidden(true, animated: false)
    
    let coordinator = HistoryCoordinator(
      router: NavigationControllerRouter(
        rootViewController: navigationController
      ),
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
    )
    return coordinator
  }
  
  func createTonHistoryListModule(
    wallet: Wallet) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, Void> {
    let listModule = HistoryListAssembly.module(
      wallet: wallet,
      paginationLoader: dependencies.keeperCoreMainAssembly.loadersAssembly.historyTonEventsPaginationLoader(
        wallet: wallet
      ),
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider())
    )
    return listModule
  }
  
  func createJettonHistoryListModule(
    jettonInfo: JettonInfo,
    wallet: Wallet
  ) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, Void> {
    let listModule = HistoryListAssembly.module(
      wallet: wallet,
      paginationLoader: dependencies.keeperCoreMainAssembly.loadersAssembly.historyJettonEventsPaginationLoader(
        wallet: wallet,
        jettonInfo: jettonInfo
      ),
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider())
    )
    return listModule
  }
}

extension HistoryModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    
    public init(coreAssembly: TKCore.CoreAssembly,
                keeperCoreMainAssembly: KeeperCore.MainAssembly) {
      self.coreAssembly = coreAssembly
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
    }
  }
}
