import Foundation
import SignerLocalize

protocol EditWalletNameViewModelConfigurator: AnyObject {
  var continueButtonTitle: String { get }
  
  func handleContinueButtonTapped() async
  func isContinueButtonEnabledOnStart() -> Bool
}

final class CreateEditWalletNameViewModelConfigurator: EditWalletNameViewModelConfigurator {
  var continueButtonTitle: String {
    SignerLocalize.Actions.continue_action
  }
  
  func handleContinueButtonTapped() async {
    return
  }
  
  func isContinueButtonEnabledOnStart() -> Bool {
    return false
  }
}

final class EditEditWalletNameViewModelConfigurator: EditWalletNameViewModelConfigurator {
  var continueButtonTitle: String {
    SignerLocalize.Actions.save
  }
  
  func handleContinueButtonTapped() async {
    return
  }
  
  func isContinueButtonEnabledOnStart() -> Bool {
    return true
  }
}
