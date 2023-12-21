//
//  CreatePasscodeConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import Foundation
import WalletCoreCore

struct CreatePasscodeConfigurator: PasscodeInputPresenterConfigurator {
  var didFinishBiometry: (() -> Void)?
  
  let title: String = "Create new passcode"
  var passcodeBiometry: PasscodeInputBiometry { .none }
  
  var didFinish: ((_ passcode: Passcode) -> Void)?
  var didFailed: (() -> Void)?
  
  func validateInput(_ input: String) -> PasscodeInputPresenterValidation {
    .filled
  }
}
