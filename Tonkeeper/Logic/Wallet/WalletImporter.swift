//
//  WalletImporter.swift
//  Tonkeeper
//
//  Created by Grigory on 30.6.23..
//

import Foundation
import WalletCore

struct WalletImporter {
  
  enum Error: Swift.Error {
    case failedToImportWallet(error: Swift.Error)
  }
  
  private let keeperController: KeeperController
  private let passcodeController: PasscodeController
  private let mnemonic: [String]
  
  init(keeperController: KeeperController,
       passcodeController: PasscodeController,
       mnemonic: [String]) {
    self.keeperController = keeperController
    self.passcodeController = passcodeController
    self.mnemonic = mnemonic
  }

  func importWallet(with passcode: Passcode) throws {
    do {
      try keeperController.addWallet(with: mnemonic)
      try passcodeController.setPasscode(passcode)
    } catch {
      throw Error.failedToImportWallet(error: error)
    }
  }
}
