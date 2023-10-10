//
//  SettingsSecurityAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 10.10.23..
//

import Foundation
import WalletCore

struct SettingsSecurityAssembly {
  static func module(biometryAuthentificator: BiometryAuthentificator,
                     settingsController: SettingsController,
                     output: SettingsListModuleOutput?) -> Module<SettingsListViewController, Void> {
    let presenter = SettingsSecurityPresenter(
      biometryAuthentificator: biometryAuthentificator,
      settingsController: settingsController)
    let viewController = SettingsListViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}
