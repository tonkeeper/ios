//
//  WalletImporter.swift
//  Tonkeeper
//
//  Created by Grigory on 30.6.23..
//

import Foundation
import WalletCoreKeeper
import WalletCoreCore

struct WalletImporter {
  
  enum Error: Swift.Error {
    case failedToImportWallet(error: Swift.Error)
  }
  
  private let walletsController: WalletsController
  private let passcodeController: PasscodeController
  private let mnemonic: [String]
  
  init(walletsController: WalletsController,
       passcodeController: PasscodeController,
       mnemonic: [String]) {
    self.walletsController = walletsController
    self.passcodeController = passcodeController
    self.mnemonic = mnemonic
  }

  func importWallet(with passcode: Passcode) throws {
    do {
      try walletsController.addWallet(with: Mnemonic(mnemonicWords: mnemonic))
      try passcodeController.setPasscode(passcode)
    } catch {
      throw Error.failedToImportWallet(error: error)
    }
  }
}
