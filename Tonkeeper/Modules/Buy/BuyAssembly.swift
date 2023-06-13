//
//  BuyAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit

struct BuyAssembly {
  func buyListModule(output: BuyListModuleOutput) -> Module<BuyListViewController, Void> {
    let presenter = BuyListPresenter(buyListServiceBuilder: BuyListServiceBuilder())
    presenter.output = output
    let viewController = BuyListViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}


