//
//  SettingsListAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 25.9.23..
//

import Foundation

struct SettingsListAssembly {
  static func module(output: SettingsListModuleOutput?) -> Module<SettingsListViewController, SettingsListModuleInput> {
    let presenter = SettingsListPresenter()
    presenter.output = output
    
    let viewController = SettingsListViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
