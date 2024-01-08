//
//  SettingsRecoveryPhraseAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 11.10.23..
//

import Foundation
import WalletCoreKeeper
import WalletCoreCore

struct SettingsRecoveryPhraseAssembly {
  static func module(walletProvider: WalletProvider,
                     isBackup: Bool = false,
                     output: SettingsRecoveryPhraseModuleOutput?) -> Module<SettingsRecoveryPhraseViewController, SettingsRecoveryPhraseModuleInput> {
    let presenter = SettingsRecoveryPhrasePresenter(
      walletProvider: walletProvider,
      isBackup: isBackup
    )
    presenter.output = output
    
    let viewController = SettingsRecoveryPhraseViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
