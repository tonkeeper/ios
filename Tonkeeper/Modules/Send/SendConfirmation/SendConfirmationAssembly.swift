//
//  SendConfirmationAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation
import WalletCoreKeeper
import BigInt

struct SendConfirmationAssembly {
  static func module(sendController: SendController,
                     output: SendConfirmationModuleOutput?) -> Module<SendConfirmationViewController, SendConfirmationModuleInput> {
    let presenter = SendConfirmationPresenter(sendController: sendController)
    let viewController = SendConfirmationViewController(presenter: presenter)
    
    presenter.output = output
    presenter.viewInput = viewController
    
    sendController.delegate = presenter
    
    return Module(view: viewController, input: presenter)
  }
}
