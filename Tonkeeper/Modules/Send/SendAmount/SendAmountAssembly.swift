//
//  SendAmountAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation
import WalletCore

struct SendAmountAssembly {
  static func module(address: String,
                     comment: String?,
                     inputCurrencyFormatter: NumberFormatter,
                     sendInputController: SendInputController,
                     sendController: SendController,
                     output: SendAmountModuleOutput?) -> Module<SendAmountViewController, SendAmountModuleInput> {
    
    let presenter = SendAmountPresenter(inputCurrencyFormatter: inputCurrencyFormatter,
                                        sendInputController: sendInputController,
                                        sendController: sendController,
                                        address: address,
                                        comment: comment)
    presenter.output = output
    
    let viewController = SendAmountViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
