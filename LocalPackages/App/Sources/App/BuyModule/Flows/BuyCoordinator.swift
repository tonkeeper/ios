import UIKit
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

public final class BuyCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  private let wallet: Wallet
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(wallet: Wallet,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: ViewControllerRouter) {
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openBuyList()
  }
}

private extension BuyCoordinator {
  func openBuyList() {
    let module = BuyListAssembly.module(
      buyListController: keeperCoreMainAssembly.buyListController(
        wallet: wallet,
        isMarketRegionPickerAvailable: coreAssembly.featureFlagsProvider.isMarketRegionPickerAvailable
      )
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didSelectItem = { [weak self, weak bottomSheetViewController] url in
      guard let bottomSheetViewController else { return }
      self?.openWebView(url: url, fromViewController: bottomSheetViewController)
    }
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openWebView(url: URL, fromViewController: UIViewController) {
    let webViewController = TKWebViewController(url: url)
    let navigationController = UINavigationController(rootViewController: webViewController)
    navigationController.modalPresentationStyle = .fullScreen
    navigationController.configureTransparentAppearance()
    fromViewController.present(navigationController, animated: true)
  }
}

//final class BuyCoordinator: Coordinator<Router<ModalCardContainerViewController>> {
//
//  private let walletCoreAssembly: WalletCoreAssembly
//  
//  init(router: Router<ModalCardContainerViewController>,
//       walletCoreAssembly: WalletCoreAssembly) {
//    self.walletCoreAssembly = walletCoreAssembly
//    super.init(router: router)
//  }
//  
//  override func start() {
//    showBuyList()
//  }
//}
//
//private extension BuyCoordinator {
//  func showBuyList() {
//    let module = BuyListAssembly.module(
//      fiatMethodsController: walletCoreAssembly.fiatMethodsController(), 
//      output: self
//    )
//    router.rootViewController.content = module.view
//  }
//}
//
//// MARK: - BuyListModuleOutput
//
//extension BuyCoordinator: BuyListModuleOutput {
//  func buyListModule(_ buyListModule: BuyListModuleInput,
//                     showFiatMethodPopUp fiatMethod: FiatMethodViewModel) {
//    let module = FiatMethodPopUpAssembly.module(fiatMethodItem: fiatMethod,
//                                                fiatMethodsController: walletCoreAssembly.fiatMethodsController(),
//                                                urlOpener: walletCoreAssembly.coreAssembly.urlOpener(),
//                                                output: self)
//    let modalCardContainerViewController = ModalCardContainerViewController(content: module.view)
//    modalCardContainerViewController.headerSize = .small
//    
//    router.present(modalCardContainerViewController)
//  }
//  
//  func buyListModule(_ buyListModule: BuyListModuleInput,
//                     showWebView url: URL) {
//    let webViewController = WebViewController(url: url)
//    let navigationController = UINavigationController(rootViewController: webViewController)
//    navigationController.modalPresentationStyle = .fullScreen
//    navigationController.configureTransparentAppearance()
//    router.present(navigationController)
//  }
//}
//
//extension BuyCoordinator: FiatMethodPopUpModuleOutput {
//  func fiatMethodPopUpModule(_ module: FiatMethodPopUpModuleInput, 
//                             openURL url: URL) {
//    router.dismiss { [weak router] in
//      let webViewController = WebViewController(url: url)
//      let navigationController = UINavigationController(rootViewController: webViewController)
//      navigationController.modalPresentationStyle = .fullScreen
//      navigationController.configureTransparentAppearance()
//      router?.present(navigationController)
//    }
//  }
//}
