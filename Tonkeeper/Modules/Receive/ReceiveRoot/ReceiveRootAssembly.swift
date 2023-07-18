//
//  ReceiveRootAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation
import WalletCore

struct ReceiveRootAssembly {
  static func module(qrCodeGenerator: QRCodeGenerator,
                     deeplinkGenerator: DeeplinkGenerator,
                     receiveController: ReceiveController,
                     output: ReceiveRootModuleOutput?) -> Module<ReceiveRootViewController, ReceiveRootModuleInput> {
    let presenter = ReceiveRootPresenter(qrCodeGenerator: qrCodeGenerator,
                                         deeplinkGenerator: deeplinkGenerator,
                                         receiveController: receiveController)
    presenter.output = output
    let viewController = ReceiveRootViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
