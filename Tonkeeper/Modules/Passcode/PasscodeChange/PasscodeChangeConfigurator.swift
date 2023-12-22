import Foundation
import WalletCoreKeeper
import WalletCoreCore
import UIKit

final class PasscodeChangeConfigurator: PasscodeInputBiometryPresenterConfigurator {
  
  let title: String = "Enter currnet passcode"
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
  private let securitySettingsController: SecuritySettingsController
  private let biometryAuthentificator: BiometryAuthentificator
  
  init(passcodeController: PasscodeController,
       securitySettingsController: SecuritySettingsController,
       biometryAuthentificator: BiometryAuthentificator) {
    self.passcodeController = passcodeController
    self.securitySettingsController = securitySettingsController
    self.biometryAuthentificator = biometryAuthentificator
  }
  
  func checkBiometryAvailability() -> PasscodeInputBiometry {
    .none
  }
  
  func evaluateBiometryAuth() {}
}
