//
//  TonConnectConfirmationAssembly.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import UIKit
import WalletCore

struct TonConnectConfirmationAssembly {
  static func module(output: TonConnectConfirmationModuleOutput?) -> Module<TonConnectConfirmationViewController, TonConnectConfirmationPresenterInput> {
    
    let presenter = TonConnectConfirmationPresenter()
    let viewController = TonConnectConfirmationViewController(presenter: presenter)
    
    presenter.viewInput = viewController
    presenter.output = output
    
    return Module(view: viewController, input: presenter)
  }
}
