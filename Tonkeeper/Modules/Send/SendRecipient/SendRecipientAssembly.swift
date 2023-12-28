//
//  SendRecipientAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation
import WalletCoreKeeper

struct SendRecipientAssembly {
  static func module(sendRecipientController: SendRecipientController,
                     commentLengthValidator: SendRecipientCommentLengthValidator,
                     knownAccounts: KnownAccounts,
                     recipient: Recipient?,
                     output: SendRecipientModuleOutput?) -> Module<SendRecipientViewController, SendRecipientModuleInput> {
    let presenter = SendRecipientPresenter(sendRecipientController: sendRecipientController,
                                           commentLengthValidator: commentLengthValidator,
                                           knownAccounts: knownAccounts,
                                           recipient: recipient)
    presenter.output = output
    
    let viewController = SendRecipientViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
