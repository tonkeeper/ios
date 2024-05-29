import Foundation
import TKLocalize

final class AddWalletCustomizeWalletViewModelConfigurator: CustomizeWalletViewModelConfigurator {
  var didCustomizeWallet: (() -> Void)?
  
  var continueButtonMode: CustomizeWalletViewModelContinueButtonMode {
    .visible(title: TKLocales.Actions.continue_action) { [weak self] in
      self?.didCustomizeWallet?()
    }
  }
  
  func didSelectColor() {}
  func didSelectEmoji() {}
  func didEditName() {}
}
