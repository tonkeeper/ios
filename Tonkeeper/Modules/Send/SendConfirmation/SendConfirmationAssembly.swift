//
//  SendConfirmationAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation
import WalletCore

struct SendConfirmationAssembly {
  static func module(transactionModel: SendTransactionModel,
                     sendController: SendController,
                     output: SendConfirmationModuleOutput?) -> Module<SendConfirmationViewController, SendConfirmationModuleInput> {
    let presenter = SendConfirmationPresenter(
      sendController: sendController,
      transactionModel: transactionModel
    )
    let viewController = SendConfirmationViewController(presenter: presenter)
    
    presenter.output = output
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
