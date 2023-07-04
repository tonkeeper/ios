//
//  SendAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit
import WalletCore

struct SendAssembly {
  
  let qrScannerAssembly: QRScannerAssembly
  let walletCoreAssembly: WalletCoreAssembly
  
  init(qrScannerAssembly: QRScannerAssembly,
       walletCoreAssembly: WalletCoreAssembly) {
    self.qrScannerAssembly = qrScannerAssembly
    self.walletCoreAssembly = walletCoreAssembly
  }
  
  func sendRecipientModule(output: SendRecipientModuleOutput,
                           address: String?) -> Module<UIViewController, SendRecipientModuleInput> {
    let presenter = SendRecipientPresenter(
      commentLengthValidator: DefaultSendRecipientCommentLengthValidator(),
      address: address
    )
    presenter.output = output
    let viewController = SendRecipientViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: presenter)
  }
  
  func sendAmountModule(output: SendAmountModuleOutput) -> Module<UIViewController, Void> {
    let presenter = SendAmountPresenter(primaryCurrencyFormatter: .currencyFormatter,
                                        secondaryCurrencyFormatter: .currencyFormatter,
                                        inputCurrencyFormatter: .currencyFormatter)
    presenter.output = output
    let viewController = SendAmountViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: Void())
  }
  
  func sendConfirmationModule(output: SendConfirmationModuleOutput) -> Module<UIViewController, Void> {
    let presenter = SendConfirmationPresenter()
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
  
}

