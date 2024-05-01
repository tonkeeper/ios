import Foundation

protocol EditWalletNameViewModelConfigurator: AnyObject {
  var continueButtonTitle: String { get }
  
  func handleContinueButtonTapped() async
}

final class CreateEditWalletNameViewModelConfigurator: EditWalletNameViewModelConfigurator {
  var continueButtonTitle: String {
    "Continue"
  }
  
  func handleContinueButtonTapped() async {
    return
  }
}

final class EditEditWalletNameViewModelConfigurator: EditWalletNameViewModelConfigurator {
  var continueButtonTitle: String {
    "Save"
  }
  
  func handleContinueButtonTapped() async {
    return
  }
}
