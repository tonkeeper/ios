//
//  SendConfirmationAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation
import WalletCore
import BigInt

struct SendConfirmationAssembly {
  static func module(address: String,
                     itemTransferModel: ItemTransferModel,
                     comment: String?,
                     sendController: SendController,
                     output: SendConfirmationModuleOutput?) -> Module<SendConfirmationViewController, SendConfirmationModuleInput> {
    let presenter = SendConfirmationPresenter(
      address: address,
      itemTransferModel: itemTransferModel,
      comment: comment,
      sendController: sendController
    )
    let viewController = SendConfirmationViewController(presenter: presenter)
    
    presenter.output = output
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
