//
//  SendRecipientAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation
import WalletCore

struct SendRecipientAssembly {
  static func module(commentLengthValidator: SendRecipientCommentLengthValidator,
                     addressValidator: AddressValidator,
                     address: String?,
                     output: SendRecipientModuleOutput?) -> Module<SendRecipientViewController, SendRecipientModuleInput> {
    let presenter = SendRecipientPresenter(commentLengthValidator: commentLengthValidator,
                                           addressValidator: addressValidator,
                                           address: address)
    presenter.output = output
    
    let viewController = SendRecipientViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
