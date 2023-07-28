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
                     inputCurrencyFormatter: NumberFormatter,
                     sendInputController: SendInputController,
                     output: SendAmountModuleOutput?) -> Module<SendAmountViewController, SendAmountModuleInput> {
    
    let presenter = SendAmountPresenter(inputCurrencyFormatter: inputCurrencyFormatter,
                                        sendInputController: sendInputController,
                                        address: address)
    presenter.output = output
    
    let viewController = SendAmountViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
