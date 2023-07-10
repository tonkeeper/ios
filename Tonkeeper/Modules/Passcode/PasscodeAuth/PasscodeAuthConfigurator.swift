//
//  PasscodeAuthConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 10.7.23..
//

import Foundation
import WalletCore

final class PasscodeAuthConfigurator: PasscodeInputPresenterConfigurator {
  let title: String = "Enter passcode"
  var isBiometryAvailable: Bool {
    // TBD: get from settings if turned on
    false
  }
  
  var didFinish: ((_ passcode: Passcode) -> Void)?
  var didFailed: (() -> Void)?
  
  func validateInput(_ input: String) -> PasscodeInputPresenterValidation {
    do {
      let storedPasscode = try passcodeController.getPasscode()
      let inputPasscode = try Passcode(value: input)
      if inputPasscode == storedPasscode {
        return .success
      } else {
        return .failed
      }
    } catch {
      return .failed
    }
  }
  
  private let passcodeController: PasscodeController
  
  init(passcodeController: PasscodeController) {
    self.passcodeController = passcodeController
  }
}
