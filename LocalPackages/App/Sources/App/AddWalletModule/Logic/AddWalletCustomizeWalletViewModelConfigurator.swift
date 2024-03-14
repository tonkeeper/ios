import Foundation

final class AddWalletCustomizeWalletViewModelConfigurator: CustomizeWalletViewModelConfigurator {
  var didCustomizeWallet: (() -> Void)?
  
  var continueButtonMode: CustomizeWalletViewModelContinueButtonMode {
    .visible(title: "Continue") { [weak self] in
      self?.didCustomizeWallet?()
    }
  }
  
  func didSelectColor() {}
  func didSelectEmoji() {}
  func didEditName() {}
}
