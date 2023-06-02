//
//  SendAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit

struct SendAssembly {
  
  let qrScannerAssembly: QRScannerAssembly
  
  init(qrScannerAssembly: QRScannerAssembly) {
    self.qrScannerAssembly = qrScannerAssembly
  }
  
  func sendRecipientModule(output: SendRecipientModuleOutput) -> Module<UIViewController, Void> {
    let presenter = SendRecipientPresenter(commentLengthValidator: DefaultSendRecipientCommentLengthValidator())
    presenter.output = output
    let viewController = SendRecipientViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: Void())
  }
  
  func sendAmountModule(output: SendAmountModuleOutput) -> Module<UIViewController, Void> {
    let presenter = SendAmountPresenter(currencyFormatter: .currencyFormatter)
    presenter.output = output
    let viewController = SendAmountViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: Void())
  }
}

private extension SendAssembly {
  
}

