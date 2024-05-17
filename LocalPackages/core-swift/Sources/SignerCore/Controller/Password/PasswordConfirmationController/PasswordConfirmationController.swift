import Foundation
import CoreComponents

public final class PasswordConfirmationController {
  
  private let passwordRepository: PasswordRepository
  
  init(passwordRepository: PasswordRepository) {
    self.passwordRepository = passwordRepository
  }
  
  public func validatePasscodeInput(_ password: String) -> Bool {
    do {
      let storedPassword = try passwordRepository.getPassword()
      return password == storedPassword
    } catch {
      return false
    }
  }
}
