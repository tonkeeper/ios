//
//  CollectibleAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 21.8.23..
//

import UIKit
import TKCore
import WalletCoreKeeper

struct CollectibleDetailsAssembly {
  static func module(collectibleDetailsController: CollectibleDetailsController,
                     urlOpener: URLOpener,
                     output: CollectibleDetailsModuleOutput?) -> Module<CollectibleDetailsViewController, CollectibleDetailsModuleInput> {
    let presenter = CollectibleDetailsPresenter(
      collectibleDetailsController: collectibleDetailsController,
      urlOpener: urlOpener
    )
    presenter.output = output
    
    collectibleDetailsController.delegate = presenter
    
    let viewController = CollectibleDetailsViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
