//
//  SettingsCurrencyPickerAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 3.10.23..
//

import Foundation
import WalletCore

struct SettingsCurrencyPickerAssembly {
  static func module(settingsController: SettingsController,
                     output: SettingsListModuleOutput?) -> Module<SettingsListViewController, SettingsListModuleInput> {
    let presenter = SettingsCurrencyPickerPresenter(settingsController: settingsController)
    presenter.output = output
    
    let viewController = SettingsListViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
