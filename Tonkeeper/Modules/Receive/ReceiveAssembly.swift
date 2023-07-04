//
//  ReceiveAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit
import WalletCore

struct ReceiveAssembly {
  
  let walletCoreAssembly: WalletCoreAssembly
  
  func receieveModule(output: ReceiveModuleOutput,
                      address: String) -> Module<UIViewController, Void> {
    let presenter = ReceivePresenter(qrCodeGenerator: qrCodeGenerator,
                                     deeplinkGenerator: walletCoreAssembly.deeplinkGenerator,
                                     address: address)
    presenter.output = output
    let viewController = ReceiveViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}

private extension ReceiveAssembly {
  var qrCodeGenerator: QRCodeGenerator {
    DefaultQRCodeGenerator()
  }
}

