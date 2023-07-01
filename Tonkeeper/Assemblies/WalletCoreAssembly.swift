//
//  WalletCoreAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import Foundation
import WalletCore

final class WalletCoreAssembly {
  
  let coreAssembly: CoreAssembly
  let walletCoreContainer = WalletCoreContainer()
  
  init(coreAssembly: CoreAssembly) {
    self.coreAssembly = coreAssembly
  }
  
  lazy var keeperController: KeeperController = walletCoreContainer.keeperController(url: coreAssembly.documentsURL)
  
  lazy var passcodeController: PasscodeController = walletCoreContainer.passcodeController()
}
