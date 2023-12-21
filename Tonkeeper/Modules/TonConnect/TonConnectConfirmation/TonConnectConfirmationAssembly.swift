//
//  TonConnectConfirmationAssembly.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import UIKit
import WalletCoreKeeper

struct TonConnectConfirmationAssembly {
  static func module(model: TonConnectConfirmationModel,
                     output: TonConnectConfirmationModuleOutput?) -> Module<TonConnectConfirmationViewController, TonConnectConfirmationPresenterInput> {
    
    let presenter = TonConnectConfirmationPresenter(
      model: model,
      transactionBuilder: ActivityListTransactionBuilder(
        accountEventActionContentProvider: TonConnectConfirmationAccountEventActionContentProvider()
      )
    )
    let viewController = TonConnectConfirmationViewController(presenter: presenter)
    
    presenter.viewInput = viewController
    presenter.output = output
    
    return Module(view: viewController, input: presenter)
  }
}
