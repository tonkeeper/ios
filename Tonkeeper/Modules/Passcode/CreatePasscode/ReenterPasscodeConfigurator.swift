//
//  ReenterPasscodeConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import Foundation
import WalletCore

struct ReenterPasscodeConfigurator: PasscodeInputPresenterConfigurator {
  let title: String = "Re-enter passcode"
  var isBiometryAvailable: Bool { false }
    
  var didFinish: ((_ passcode: Passcode) -> Void)?
  var didFailed: (() -> Void)?
  
  private let createdPasscode: Passcode
  
  init(createdPasscode: Passcode) {
    self.createdPasscode = createdPasscode
  }
  
  func validateInput(_ input: String) -> PasscodeInputPresenterValidation {
    do {
      let passcode = try Passcode(value: input)
      return createdPasscode == passcode ? .success : .failed
    } catch {
      return .failed
    }
  }
}
