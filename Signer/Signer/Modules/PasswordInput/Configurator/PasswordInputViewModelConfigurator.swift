import UIKit
import SignerCore
import SignerLocalize

protocol PasswordInputViewModelConfigurator: AnyObject {
  var title: String { get }
  var showKeyboardWhileAppear: Bool { get }
  var textFieldCaption: String? { get }
  
  func validateInput(_ input: String) async -> Bool
  func isContinueEnable(_ input: String) -> Bool
}

extension PasswordInputViewModelConfigurator {
  func isContinueEnable(_ input: String) -> Bool {
    input.count >= 4
  }
}

final class CreatePasswordPasswordInputViewModelConfigurator: PasswordInputViewModelConfigurator {
  
  init(showKeyboardWhileAppear: Bool,
       title: String) {
    self.showKeyboardWhileAppear = showKeyboardWhileAppear
    self.title = title
  }
  
  // MARK: - PasswordInputViewModelConfigurator
  
  var textFieldCaption: String? {
    SignerLocalize.Password.Create.Textfield.caption
  }
  var showKeyboardWhileAppear: Bool
  let title: String
  
  func validateInput(_ input: String) async -> Bool {
    input.count >= 4
  }
}

final class ReenterPasswordPasswordInputViewModelConfigurator: PasswordInputViewModelConfigurator {
  let title: String
  private let password: String

  init(title: String,
       password: String) {
    self.title = title
    self.password = password
  }

  // MARK: - PasswordInputViewModelConfigurator
  
  var textFieldCaption: String? {
   nil
  }
  var showKeyboardWhileAppear: Bool {
    true
  }
  
  func validateInput(_ input: String) async -> Bool {
    let isValid = input == password
    if !isValid {
      await UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    return isValid
  }
}

final class EnterPasswordPasswordInputViewModelConfigurator: PasswordInputViewModelConfigurator {
  
  var textFieldCaption: String? {
    nil
  }
  private let mnemonicsRepository: MnemonicsRepository
  private let oldMnemonicRepository: MnemonicsRepository
  let title: String
  
  init(mnemonicsRepository: MnemonicsRepository,
       oldMnemonicRepository: MnemonicsRepository,
       title: String) {
    self.mnemonicsRepository = mnemonicsRepository
    self.oldMnemonicRepository = oldMnemonicRepository
    self.title = title
  }
  
  // MARK: - PasswordInputViewModelConfigurator

  var showKeyboardWhileAppear: Bool {
    true
  }
  
  func validateInput(_ input: String) async -> Bool {
    var isValid = await mnemonicsRepository.checkIfPasswordValid(input)
    if !isValid {
      isValid = await oldMnemonicRepository.checkIfPasswordValid(input)
    }

    if !isValid {
      await UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    return isValid
  }
}
