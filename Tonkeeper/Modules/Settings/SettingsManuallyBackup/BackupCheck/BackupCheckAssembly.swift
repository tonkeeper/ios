//
//  EnterMnemonicAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import Foundation
import WalletCoreCore

struct BackupCheckAssembly {
  static func create(walletProvider: WalletProvider,
                     output: BackupCheckModuleOutput) -> Module<BackupCheckViewController, Void> {
    let presenter = BackupCheckPresenter(walletProvider: walletProvider)
    presenter.output = output
    
    let viewController = BackupCheckViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}
