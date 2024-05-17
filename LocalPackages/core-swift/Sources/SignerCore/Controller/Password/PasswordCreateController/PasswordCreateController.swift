import Foundation
import CoreComponents

public final class PasswordCreateController {
  
  private let passwordRepository: PasswordRepository
  
  init(passwordRepository: PasswordRepository) {
    self.passwordRepository = passwordRepository
  }
  
  public func createPassword(_ input: String) throws {
    try passwordRepository.savePassword(input)
  }
  
  public func validatePasscwordInput(_ input: String) -> Bool {
    do {
      let storedPassword = try passwordRepository.getPassword()
      return input == storedPassword
    } catch {
      return false
    }
  }
}
