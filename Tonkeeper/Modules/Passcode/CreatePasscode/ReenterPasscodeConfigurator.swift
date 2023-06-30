//
//  ReenterPasscodeConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import Foundation

struct ReenterPasscodeConfigurator: PasscodeInputPresenterConfigurator {
  let title: String = "Re-enter passcode"
  var isBiometryAvailable: Bool { false }
    
  var didFinish: ((_ passcode: String) -> Void)?
  var didFailed: (() -> Void)?
  
  private let createdPasscode: String
  
  init(createdPasscode: String) {
    self.createdPasscode = createdPasscode
  }
  
  func validateInput(_ input: String) -> PasscodeInputPresenterValidation {
    createdPasscode == input ? .success : .failed
  }
}
