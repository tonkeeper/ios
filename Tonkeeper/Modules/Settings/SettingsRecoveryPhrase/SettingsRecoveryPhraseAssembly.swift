//
//  SettingsRecoveryPhraseAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 11.10.23..
//

import Foundation
import WalletCore

struct SettingsRecoveryPhraseAssembly {
  static func module(keeperController: KeeperController,
                     output: SettingsRecoveryPhraseModuleOutput?) -> Module<SettingsRecoveryPhraseViewController, SettingsRecoveryPhraseModuleInput> {
    let presenter = SettingsRecoveryPhrasePresenter(keeperController: keeperController)
    presenter.output = output
    
    let viewController = SettingsRecoveryPhraseViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
