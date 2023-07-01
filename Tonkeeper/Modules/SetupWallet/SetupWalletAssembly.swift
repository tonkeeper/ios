//
//  SetupWalletAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import Foundation

struct SetupWalletAssembly {
  static func create(output: SetupWalletModuleOutput) -> Module<SetupWalletViewController, Void> {
    let presenter = SetupWalletPresenter()
    presenter.output = output
    
    let viewController = SetupWalletViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}
