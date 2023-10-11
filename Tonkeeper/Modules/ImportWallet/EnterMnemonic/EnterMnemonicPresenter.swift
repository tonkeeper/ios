//
//  EnterMnemonicEnterMnemonicPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import Foundation
import WalletCore

final class EnterMnemonicPresenter {
  
  // MARK: - Module
  
  weak var viewInput: EnterMnemonicViewInput?
  weak var output: EnterMnemonicModuleOutput?
  
  // MARK: - Dependencies
  
  private let mnemonicValidator = MnemonicValidator()
}

// MARK: - EnterMnemonicPresenterIntput

extension EnterMnemonicPresenter: EnterMnemonicPresenterInput {
  func viewDidLoad() {
    updateView()
  }
  
  func validate(word: String) -> Bool {
    mnemonicValidator.validate(word: word)
  }
  
  func didEnterMnemonic(_ mnemonic: [String]) {
    let isValid = mnemonicValidator.validate(mnemonic: mnemonic)
    if isValid {
      output?.didInputMnemonic(mnemonic)
    } else {
      viewInput?.showMnemonicValidationError()
    }
  }
}

// MARK: - EnterMnemonicModuleInput

extension EnterMnemonicPresenter: EnterMnemonicModuleInput {}

// MARK: - Private

private extension EnterMnemonicPresenter {
  func updateView() {
    let title = String.title
      .attributed(with: .h2, alignment: .center, color: .Text.primary)
    let description = String.description
      .attributed(with: .body1, alignment: .center, color: .Text.secondary)
    let model = EnterMnemonicView.Model(
      scrollContainerModel: .init(
        title: title,
        description: description),
      continueButtonTitle: .continueButtonTitle)
    viewInput?.update(with: model)
  }
}

private extension String {
  static let title = "Enter your\nrecovery phrase"
  static let description = "To restore access to your wallet, enter\nthe 24 secret recovery words given\nto you when you created your wallet."
  static let continueButtonTitle = "Continue"
}
