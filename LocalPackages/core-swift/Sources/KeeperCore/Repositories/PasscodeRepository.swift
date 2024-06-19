import Foundation
import CoreComponents

public protocol PasscodeRepository {
  func savePasscode(_ passcode: Passcode) throws
  func getPasscode() throws -> Passcode
  func deletePasscode() throws
}

struct PasscodeRepositoryImplementation: PasscodeRepository {
  
  private let passcodeVault: PasscodeVault
  
  init(passcodeVault: PasscodeVault) {
    self.passcodeVault = passcodeVault
  }
  
  func savePasscode(_ passcode: Passcode) throws {
    try passcodeVault.save(passcode)
  }
  
  func getPasscode() throws -> Passcode {
    try passcodeVault.load()
  }
  
  func deletePasscode() throws {
    try passcodeVault.delete()
  }
}
