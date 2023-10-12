//
//  SettingsListAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 25.9.23..
//

import Foundation
import WalletCore

struct SettingsListAssembly {
  static func module(settingsController: SettingsController,
                     logoutController: LogoutController,
                     output: SettingsListModuleOutput?) -> Module<SettingsListViewController, SettingsListModuleInput> {
    let presenter = SettingsListPresenter(
      settingsController: settingsController,
      logoutController: logoutController
    )
    presenter.output = output
    
    let viewController = SettingsListViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
