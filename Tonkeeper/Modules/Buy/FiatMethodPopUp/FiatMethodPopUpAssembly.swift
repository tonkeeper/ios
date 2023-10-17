//
//  FiatMethodPopUpAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 16.10.23..
//

import Foundation
import WalletCore
import TKCore

struct FiatMethodPopUpAssembly {
  static func module(fiatMethodItem: FiatMethodViewModel,
                     fiatMethodsController: FiatMethodsController,
                     urlOpener: URLOpener,
                     output: FiatMethodPopUpModuleOutput?) -> Module<FiatMethodPopUpViewController, FiatMethodPopUpModuleInput> {
    let presenter = FiatMethodPopUpPresenter(
      fiatMethodItem: fiatMethodItem,
      fiatMethodsController: fiatMethodsController,
      urlOpener: urlOpener
    )
    presenter.output = output
    
    let viewController = FiatMethodPopUpViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
