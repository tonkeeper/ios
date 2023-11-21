//
//  BuyCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit
import WalletCoreKeeper

final class BuyCoordinator: Coordinator<Router<ModalCardContainerViewController>> {
  
  private let walletCoreAssembly: WalletCoreAssembly
  
  init(router: Router<ModalCardContainerViewController>,
       walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    super.init(router: router)
  }
  
  override func start() {
    showBuyList()
  }
}

private extension BuyCoordinator {
  func showBuyList() {
    let module = BuyListAssembly.module(
      fiatMethodsController: walletCoreAssembly.fiatMethodsController(), 
      output: self
    )
    router.rootViewController.content = module.view
  }
}

// MARK: - BuyListModuleOutput

extension BuyCoordinator: BuyListModuleOutput {
  func buyListModule(_ buyListModule: BuyListModuleInput,
                     showFiatMethodPopUp fiatMethod: FiatMethodViewModel) {
    let module = FiatMethodPopUpAssembly.module(fiatMethodItem: fiatMethod,
                                                fiatMethodsController: walletCoreAssembly.fiatMethodsController(),
                                                urlOpener: walletCoreAssembly.coreAssembly.urlOpener(),
                                                output: self)
    let modalCardContainerViewController = ModalCardContainerViewController(content: module.view)
    modalCardContainerViewController.headerSize = .small
    
    router.present(modalCardContainerViewController)
  }
  
  func buyListModule(_ buyListModule: BuyListModuleInput,
                     showWebView url: URL) {
    let webViewController = WebViewController(url: url)
    let navigationController = UINavigationController(rootViewController: webViewController)
    navigationController.modalPresentationStyle = .fullScreen
    navigationController.configureTransparentAppearance()
    router.present(navigationController)
  }
}

extension BuyCoordinator: FiatMethodPopUpModuleOutput {
  func fiatMethodPopUpModule(_ module: FiatMethodPopUpModuleInput, 
                             openURL url: URL) {
    router.dismiss { [weak router] in
      let webViewController = WebViewController(url: url)
      let navigationController = UINavigationController(rootViewController: webViewController)
      navigationController.modalPresentationStyle = .fullScreen
      navigationController.configureTransparentAppearance()
      router?.present(navigationController)
    }
  }
}
