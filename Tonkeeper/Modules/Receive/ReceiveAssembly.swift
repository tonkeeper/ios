//
//  ReceiveAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

struct ReceiveAssembly {
  func receieveModule(output: ReceiveModuleOutput) -> Module<UIViewController, Void> {
    let presenter = ReceivePresenter(qrCodeGenerator: DefaultQRCodeGenerator())
    presenter.output = output
    let viewController = ReceiveViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}

