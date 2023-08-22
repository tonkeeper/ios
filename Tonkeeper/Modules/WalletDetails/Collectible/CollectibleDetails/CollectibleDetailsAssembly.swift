//
//  CollectibleAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 21.8.23..
//

import UIKit
import WalletCore

struct CollectibleDetailsAssembly {
  static func module(collectibleDetailsController: CollectibleDetailsController,
                     output: CollectibleDetailsModuleOutput?) -> Module<CollectibleDetailsViewController, CollectibleDetailsModuleInput> {
    let presenter = CollectibleDetailsPresenter(collectibleDetailsController: collectibleDetailsController)
    presenter.output = output
    
    let viewController = CollectibleDetailsViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
