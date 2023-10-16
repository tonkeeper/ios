//
//  BuyCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit

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

extension BuyCoordinator: BuyListModuleOutput {}
