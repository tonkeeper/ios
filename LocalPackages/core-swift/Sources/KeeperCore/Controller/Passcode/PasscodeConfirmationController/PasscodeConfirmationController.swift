import Foundation
import CoreComponents

public final class PasscodeConfirmationController {
  
  private let passcodeRepository: PasscodeRepository
  private let securityStore: SecurityStore
  
  init(passcodeRepository: PasscodeRepository,
       securityStore: SecurityStore) {
    self.passcodeRepository = passcodeRepository
    self.securityStore = securityStore
  }
  
  public var isBiometryEnabled: Bool {
    get async {
      await securityStore.isBiometryEnabled
    }
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
