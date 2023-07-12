//
//  SendConfirmationSendConfirmationPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 03/06/2023.
//

import Foundation
import WalletCore

final class SendConfirmationPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendConfirmationViewInput?
  weak var output: SendConfirmationModuleOutput?
  
  // MARK: - Dependencies
  
  private let sendController: SendController
  private let transactionModel: SendTransactionModel

  init(sendController: SendController,
       transactionModel: SendTransactionModel) {
    self.sendController = sendController
    self.transactionModel = transactionModel
  }
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
    let model = transactionModel.tokenModel
    let configuration = SendConfirmationModalConfigurationBuilder.configuration(
      title: model.title,
      recipient: nil,
      recipientAddress: model.address,
      amount: model.amountToken,
      fiatAmount: model.amountFiat,
      fee: model.feeTon,
      fiatFee: model.feeFiat,
      comment: model.comment,
      tapAction: { [weak self] closure in
        guard let self = self else { return }
        Task {
          do {
            try await self.sendController.sendTransaction(boc: self.transactionModel.boc)
            Task { @MainActor in
              closure(true)
            }
          } catch {
            Task { @MainActor in
              closure(false)
            }
          }
        }
      },
      completion: { [weak self] isSuccess in
        if isSuccess {
          self?.output?.sendRecipientModuleDidFinish()
        }
      }
    )
    viewInput?.update(with: configuration)
  }
}
