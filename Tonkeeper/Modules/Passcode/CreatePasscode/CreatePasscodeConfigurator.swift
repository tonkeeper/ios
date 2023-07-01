//
//  CreatePasscodeConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import Foundation
import WalletCore

struct CreatePasscodeConfigurator: PasscodeInputPresenterConfigurator {
  let title: String = "Create new passcode"
  var isBiometryAvailable: Bool { false }
  
  var didFinish: ((_ passcode: Passcode) -> Void)?
  var didFailed: (() -> Void)?
  
  func validateInput(_ input: String) -> PasscodeInputPresenterValidation {
    .filled
  }
}
