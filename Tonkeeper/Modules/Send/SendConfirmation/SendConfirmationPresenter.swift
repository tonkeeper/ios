//
//  SendConfirmationSendConfirmationPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 03/06/2023.
//

import Foundation

final class SendConfirmationPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendConfirmationViewInput?
  weak var output: SendConfirmationModuleOutput?
}

// MARK: - SendConfirmationPresenterIntput

extension SendConfirmationPresenter: SendConfirmationPresenterInput {
  func viewDidLoad() {
    update()
  }
  
  func didTapCloseButton() {
    output?.sendConfirmationModuleDidTapCloseButton()
  }
}

// MARK: - SendConfirmationModuleInput

extension SendConfirmationPresenter: SendConfirmationModuleInput {}

// MARK: - Private

private extension SendConfirmationPresenter {
  func update() {
    
    let configuration = SendConfirmationModalConfigurationBuilder.configuration(
      title: "TON transfer",
      recipient: "kachemirova.ton",
      recipientAddress: "EQCc…9ZLD",
      amount: "5,754.32 TON",
      fiatAmount: "$ 6,328.81",
      fee: "≈ 0.007 TON",
      fiatFee: "≈ $ 0.03",
      comment: "Thank you very much!",
      tapAction: { closure in
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          closure(true)
        }
      },
      completion: { [weak self] in
        self?.output?.sendRecipientModuleDidFinish()
      }
    )
    viewInput?.update(with: configuration)
  }
}
