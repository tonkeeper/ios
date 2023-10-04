//
//  PasscodeAuthConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 10.7.23..
//

import Foundation
import WalletCore
import UIKit

final class PasscodeAuthConfigurator: PasscodeInputBiometryPresenterConfigurator {
  
  let title: String = "Enter passcode"
  var didFinish: ((_ passcode: Passcode) -> Void)?
  var didFailed: (() -> Void)?
  var didStartBiometry: (() -> Void)?
  var didFinishBiometry: ((Bool) -> Void)?
  
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
  private let biometryAuthentificator: BiometryAuthentificator
  
  init(passcodeController: PasscodeController,
       biometryAuthentificator: BiometryAuthentificator) {
    self.passcodeController = passcodeController
    self.biometryAuthentificator = biometryAuthentificator
  }
  
  func checkBiometryAvailability() -> PasscodeInputBiometry {
    let result = biometryAuthentificator.canEvaluate(policy: .deviceOwnerAuthenticationWithBiometrics)
    switch result {
    case .failure:
      return .none
    case .success(let result):
      guard result.isSuccess else {
        return .none
      }
      switch result.type {
      case .faceID:
        return .faceID
      case .touchID:
        return .touchID
      default: return .none
      }
    }
  }
  
  func evaluateBiometryAuth() {
    Task {
      await MainActor.run {
        didStartBiometry?()
      }
      let result = await biometryAuthentificator.evaluate(policy: .deviceOwnerAuthenticationWithBiometrics)
      switch result {
      case .failure:
        await MainActor.run {
          didFinishBiometry?(false)
        }
      case .success(let isSuccess):
        await MainActor.run {
          didFinishBiometry?(isSuccess)
        }
      }
    }
  }
}
