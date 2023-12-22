//
//  PasscodeInputAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import Foundation

struct PasscodeInputAssembly {
  static func create(
    output: PasscodeInputModuleOutput?,
    configurator: PasscodeInputPresenterConfigurator
  ) -> Module<PasscodeInputViewController, Void> {
    let presenter = PasscodeInputPresenter(configurator: configurator)
    presenter.output = output
    
    let viewController = PasscodeInputViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}
