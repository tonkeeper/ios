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
  lazy var walletCoreContainer = WalletCoreContainer(cacheURL: coreAssembly.documentsURL)
  
  init(coreAssembly: CoreAssembly) {
    self.coreAssembly = coreAssembly
  }
  
  lazy var keeperController: KeeperController = walletCoreContainer.keeperController()
  
  lazy var passcodeController: PasscodeController = walletCoreContainer.passcodeController()
  
  lazy var balanceController: WalletBalanceController = walletCoreContainer.walletBalanceController()
  
  var deeplinkParser: DeeplinkParser {
    walletCoreContainer.deeplinkParser()
  }
  
  var deeplinkGenerator: DeeplinkGenerator {
    walletCoreContainer.deeplinkGenerator()
  }
}
