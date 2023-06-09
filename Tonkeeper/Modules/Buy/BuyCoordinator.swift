//
//  BuyCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit

final class BuyCoordinator: Coordinator<Router<ModalCardContainerViewController>> {
  
  private let assembly: BuyAssembly
  
  init(router: Router<ModalCardContainerViewController>,
       assembly: BuyAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    showBuyList()
  }
}

private extension BuyCoordinator {
  func showBuyList() {
    let module = assembly.buyListModule(output: self)
    router.rootViewController.content = module.view
  }
}

// MARK: - BuyListModuleOutput

extension BuyCoordinator: BuyListModuleOutput {}
