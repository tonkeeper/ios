import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

public final class WalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
    router.rootViewController.tabBarItem.title = "Wallet"
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.wallet
  }
  
  public override func start() {
    openWalletContainer()
  }
}

private extension WalletCoordinator {
  func openWalletContainer() {
    let module = WalletContainerAssembly.module(
      childModuleProvider: self, 
      walletMainController: keeperCoreMainAssembly.walletMainController()
    )
    
    module.output.didTapWalletButton = { [weak self] in
      self?.openWalletPicker()
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openWalletPicker() {}
}

extension WalletCoordinator: WalletContainerViewModelChildModuleProvider {
  func getWalletBalanceModuleView() -> UIViewController {
    let module = WalletBalanceAssembly.module()
    return module.view
  }
}
