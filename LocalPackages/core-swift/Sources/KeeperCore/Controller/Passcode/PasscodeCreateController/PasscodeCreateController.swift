import Foundation
import CoreComponents

public final class PasscodeCreateController {
  
  private let passcodeRepository: PasscodeRepository
  
  init(passcodeRepository: PasscodeRepository) {
    self.passcodeRepository = passcodeRepository
  }
  
  public func createPasscode(_ passcodeInput: String) throws {
    let passcode = try Passcode(value: passcodeInput)
    try passcodeRepository.savePasscode(passcode)
  }
  
  public func validatePasscodeInput(_ passcodeInput: String) -> Bool {
    do {
      let passcode = try Passcode(value: passcodeInput)
      let storedPasscode = try passcodeRepository.getPasscode()
      return passcode == storedPasscode
    } catch {
      return false
    }
  }
}
