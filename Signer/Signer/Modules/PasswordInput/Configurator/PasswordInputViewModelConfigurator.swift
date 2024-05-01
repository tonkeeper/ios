import Foundation
import SignerCore

protocol PasswordInputViewModelConfigurator: AnyObject {
  var title: String { get }
  var showKeyboardWhileAppear: Bool { get }
  
  func validateInput(_ input: String) -> Bool
  func isContinueEnable(_ input: String) -> Bool
}

extension PasswordInputViewModelConfigurator {
  func isContinueEnable(_ input: String) -> Bool {
    !input.isEmpty
  }
}

final class CreatePasswordPasswordInputViewModelConfigurator: PasswordInputViewModelConfigurator {
  
  init(showKeyboardWhileAppear: Bool) {
    self.showKeyboardWhileAppear = showKeyboardWhileAppear
  }
  
  // MARK: - PasswordInputViewModelConfigurator
  
  var title: String {
    "Create Password"
  }
  
  var showKeyboardWhileAppear: Bool
  
  func validateInput(_ input: String) -> Bool {
    !input.isEmpty
  }
}

final class ReenterPasswordPasswordInputViewModelConfigurator: PasswordInputViewModelConfigurator {
  private let password: String

  init(password: String) {
    self.password = password
  }

  // MARK: - PasswordInputViewModelConfigurator
  
  var title: String {
    "Re-enter Password"
  }
  
  var showKeyboardWhileAppear: Bool {
    true
  }
  
  func validateInput(_ input: String) -> Bool {
    input == password
  }
}

final class EnterPasswordPasswordInputViewModelConfigurator: PasswordInputViewModelConfigurator {
  
  private let passwordRepository: PasswordRepository
  
  init(passwordRepository: PasswordRepository) {
    self.passwordRepository = passwordRepository
  }
  
  // MARK: - PasswordInputViewModelConfigurator
  
  var title: String {
    "Enter Password"
  }
  
  var showKeyboardWhileAppear: Bool {
    true
  }
  
  func validateInput(_ input: String) -> Bool {
    do {
      return try input == passwordRepository.getPassword()
    } catch {
      return false
    }
  }
}
