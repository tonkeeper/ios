//
//  CollectibleAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 21.8.23..
//

import UIKit

struct CollectibleDetailsAssembly {
  static func module(output: CollectibleDetailsModuleOutput?) -> Module<CollectibleDetailsViewController, CollectibleDetailsModuleInput> {
    let presenter = CollectibleDetailsPresenter()
    presenter.output = output
    
    let viewController = CollectibleDetailsViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
