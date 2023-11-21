//
//  WalletCreator.swift
//  Tonkeeper
//
//  Created by Grigory on 30.6.23..
//

import Foundation
import WalletCoreKeeper
import WalletCoreCore
import TonSwift

struct WalletCreator {
  
  enum Error: Swift.Error {
    case failedToCreateWallet
  }
  
  private let walletsController: WalletsController
  private let passcodeController: PasscodeController
  
  init(walletsController: WalletsController,
       passcodeController: PasscodeController) {
    self.walletsController = walletsController
    self.passcodeController = passcodeController
  }

  func create(with passcode: Passcode) throws {
    let mnemonic = try Mnemonic(mnemonicWords: Mnemonic.mnemonicNew(wordsCount: 24))
    do {
      try walletsController.addWallet(with: mnemonic)
      try passcodeController.setPasscode(passcode)
    } catch {
      throw Error.failedToCreateWallet
    }
  }
}
