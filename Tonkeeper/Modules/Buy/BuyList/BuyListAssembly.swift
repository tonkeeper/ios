//
//  BuyListAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit
import WalletCoreKeeper

struct BuyListAssembly {
  static func module(fiatMethodsController: FiatMethodsController,
                     output: BuyListModuleOutput) -> Module<BuyListViewController, Void> {
    let presenter = BuyListPresenter(
      fiatMethodsController: fiatMethodsController,
      buyListServiceBuilder: BuyListServiceBuilder()
    )
    presenter.output = output
    let viewController = BuyListViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}


