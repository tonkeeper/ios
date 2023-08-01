//
//  SendRecipientAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation
import WalletCore

struct SendRecipientAssembly {
  static func module(sendRecipientController: SendRecipientController,
                     commentLengthValidator: SendRecipientCommentLengthValidator,
                     recipient: Recipient?,
                     output: SendRecipientModuleOutput?) -> Module<SendRecipientViewController, SendRecipientModuleInput> {
    let presenter = SendRecipientPresenter(sendRecipientController: sendRecipientController,
                                           commentLengthValidator: commentLengthValidator,
                                           recipient: recipient)
    presenter.output = output
    
    let viewController = SendRecipientViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
