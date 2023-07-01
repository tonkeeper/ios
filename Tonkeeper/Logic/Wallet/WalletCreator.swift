//
//  WalletCreator.swift
//  Tonkeeper
//
//  Created by Grigory on 30.6.23..
//

import Foundation
import WalletCore
import TonSwift

struct WalletCreator {
  
  enum Error: Swift.Error {
    case failedToCreateWallet
  }
  
  private let keeperController: KeeperController
  private let passcodeController: PasscodeController
  
  init(keeperController: KeeperController,
       passcodeController: PasscodeController) {
    self.keeperController = keeperController
    self.passcodeController = passcodeController
  }

  func create(with passcode: Passcode) throws {
    let mnemonic = Mnemonic.mnemonicNew(wordsCount: 24)
    do {
      try keeperController.addWallet(with: mnemonic)
      try passcodeController.setPasscode(passcode)
    } catch {
      throw Error.failedToCreateWallet
    }
  }
}
