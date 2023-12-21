//
//  SettingsCurrencyPickerAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 3.10.23..
//

import Foundation
import WalletCoreKeeper

struct SettingsCurrencyPickerAssembly {
  static func module(settingsController: SettingsController,
                     output: SettingsListModuleOutput?) -> Module<SettingsListViewController, Void> {
    let presenter = SettingsCurrencyPickerPresenter(settingsController: settingsController)
    
    let viewController = SettingsListViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}
