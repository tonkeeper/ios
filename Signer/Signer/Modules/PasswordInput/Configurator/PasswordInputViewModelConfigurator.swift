import Foundation
import SignerCore
import SignerLocalize

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
    SignerLocalize.Password.Create.title
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
    SignerLocalize.Password.Reenter.title
  }
  
  var showKeyboardWhileAppear: Bool {
    true
  }
  
  func validateInput(_ input: String) -> Bool {
    input == password
  }
}

final class EnterPasswordPasswordInputViewModelConfigurator: PasswordInputViewModelConfigurator {
  
  private let mnemonicsRepository: MnemonicsRepository
  
  init(mnemonicsRepository: MnemonicsRepository) {
    self.mnemonicsRepository = mnemonicsRepository
  }
  
  // MARK: - PasswordInputViewModelConfigurator
  
  var title: String {
    SignerLocalize.Password.Enter.title
  }
  
  var showKeyboardWhileAppear: Bool {
    true
  }
  
  func validateInput(_ input: String) -> Bool {
    mnemonicsRepository.checkIfPasswordValid(input)
  }
}
