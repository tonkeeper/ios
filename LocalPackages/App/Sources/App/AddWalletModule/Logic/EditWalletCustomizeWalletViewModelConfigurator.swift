import Foundation

final class EditWalletCustomizeWalletViewModelConfigurator: CustomizeWalletViewModelConfigurator {
  var didCustomizeWallet: (() -> Void)?
  
  var continueButtonMode: CustomizeWalletViewModelContinueButtonMode {
    .hidden
  }
  
  func didSelectColor() {
    didCustomizeWallet?()
  }
  
  func didSelectEmoji() {
    didCustomizeWallet?()
  }
  
  func didEditName() {
    didCustomizeWallet?()
  }
}
