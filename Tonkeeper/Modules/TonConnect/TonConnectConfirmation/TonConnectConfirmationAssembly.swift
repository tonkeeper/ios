//
//  TonConnectConfirmationAssembly.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import UIKit
import WalletCore

struct TonConnectConfirmationAssembly {
  static func module(model: TonConnectConfirmationModel,
                     output: TonConnectConfirmationModuleOutput?) -> Module<TonConnectConfirmationViewController, TonConnectConfirmationPresenterInput> {
    
    let presenter = TonConnectConfirmationPresenter(
      model: model,
      transactionBuilder: ActivityListTransactionBuilder()
    )
    let viewController = TonConnectConfirmationViewController(presenter: presenter)
    
    presenter.viewInput = viewController
    presenter.output = output
    
    return Module(view: viewController, input: presenter)
  }
}
