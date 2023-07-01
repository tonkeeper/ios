//
//  EnterMnemonicAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import Foundation

struct EnterMnemonicAssembly {
  static func create(output: EnterMnemonicModuleOutput) -> Module<EnterMnemonicViewController, Void> {
    let presenter = EnterMnemonicPresenter()
    presenter.output = output
    
    let viewController = EnterMnemonicViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}
