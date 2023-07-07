//
//  SendAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit
import WalletCore

final class SendAssembly {
  
  let qrScannerAssembly: QRScannerAssembly
  let walletCoreAssembly: WalletCoreAssembly
  
  private var _sendController: SendController?
  
  init(qrScannerAssembly: QRScannerAssembly,
       walletCoreAssembly: WalletCoreAssembly) {
    self.qrScannerAssembly = qrScannerAssembly
    self.walletCoreAssembly = walletCoreAssembly
  }
  
  func sendRecipientModule(output: SendRecipientModuleOutput,
                           address: String?) -> Module<UIViewController, SendRecipientModuleInput> {
    let presenter = SendRecipientPresenter(
      commentLengthValidator: DefaultSendRecipientCommentLengthValidator(),
      addressValidator: walletCoreAssembly.addressValidator,
      address: address
    )
    presenter.output = output
    let viewController = SendRecipientViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: presenter)
  }
  
  func sendAmountModule(output: SendAmountModuleOutput,
                        address: String,
                        comment: String?) -> Module<UIViewController, Void> {
    let presenter = SendAmountPresenter(
      inputCurrencyFormatter: .inputCurrencyFormatter,
      sendInputController: walletCoreAssembly.sendInputController,
      sendController: sendController(),
      address: address,
      comment: comment
    )
    presenter.output = output
    let viewController = SendAmountViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: Void())
  }
  
  func sendConfirmationModule(output: SendConfirmationModuleOutput,
                              transactionModel: SendTransactionModel) -> Module<UIViewController, Void> {
    let presenter = SendConfirmationPresenter(
      sendController: sendController(),
      transactionModel: transactionModel
    )
    presenter.output = output
    let viewController = SendConfirmationViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: Void())
  }
  
  var deeplinkParser: DeeplinkParser {
    walletCoreAssembly.deeplinkParser
  }
}

private extension SendAssembly {
  func sendController() -> SendController {
    guard let sendController = _sendController else {
      let sendController = walletCoreAssembly.sendController()
      _sendController = sendController
      return sendController
    }
    return sendController
  }
}

