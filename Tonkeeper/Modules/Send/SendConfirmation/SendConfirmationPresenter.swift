//
//  SendConfirmationSendConfirmationPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 03/06/2023.
//

import Foundation
import WalletCore
import BigInt

final class SendConfirmationPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendConfirmationViewInput?
  weak var output: SendConfirmationModuleOutput?
  
  // MARK: - Dependencies
  
  private let sendController: SendController
  private let address: String
  private let itemTransferModel: ItemTransferModel
  private let comment: String?
  
  // MARK: - State

  init(address: String,
       itemTransferModel: ItemTransferModel,
       comment: String?,
       sendController: SendController) {
    self.sendController = sendController
    self.address = address
    self.itemTransferModel = itemTransferModel
    self.comment = comment
  }
}

// MARK: - SendConfirmationPresenterIntput

extension SendConfirmationPresenter: SendConfirmationPresenterInput {
  func viewDidLoad() {
    updateInitialState()
    Task {
      let transactionBoc = try await prepareTransaction()
      await MainActor.run {
        updateTransactionPreparedState()
      }
      let transactionInformation = try await sendController.loadTransactionInformation(itemTransferModel: itemTransferModel, boc: transactionBoc)
      await MainActor.run {
        updateTransaction(sendTransactionViewModel: transactionInformation)
      }
    }
  }
  
  func didTapCloseButton() {
    output?.sendConfirmationModuleDidTapCloseButton()
  }
}

// MARK: - SendConfirmationModuleInput

extension SendConfirmationPresenter: SendConfirmationModuleInput {}

// MARK: - Private

private extension SendConfirmationPresenter {
  func updateInitialState() {
    let model = sendController.initialSendTransactionModel(
      itemTransferModel: itemTransferModel,
      recipientAddress: address,
      comment: comment
    )
    let configuration = initialConfiguration(model: model)
    viewInput?.update(with: configuration)
  }
  
  func updateTransactionPreparedState() {
    let actionBarConfiguration = SendConfirmationModalConfigurationBuilder
      .actionBarConfiguration(
        showActivity: false,
        showActivityOnTap: true,
        tapAction: { [weak self] closure in
          self?.tapAction(closure: closure)
        },
        completion: { [weak self] isSuccess in
          self?.completion(isSuccess: isSuccess)
        })
    
    viewInput?.update(with: actionBarConfiguration)
  }
  
  func updateTransaction(sendTransactionViewModel: SendTransactionViewModel) {
    let configuration = SendConfirmationModalConfigurationBuilder
      .configuration(
        title: sendTransactionViewModel.title,
        image: .with(image: sendTransactionViewModel.image),
        recipientName: sendTransactionViewModel.recipientName,
        recipientAddress: sendTransactionViewModel.recipientAddress,
        amount: sendTransactionViewModel.amountToken,
        fiatAmount: .value(sendTransactionViewModel.amountFiat),
        fee: .value(sendTransactionViewModel.feeTon),
        fiatFee: .value(sendTransactionViewModel.feeFiat),
        comment: sendTransactionViewModel.comment,
        showActivity: false,
        showActivityOnTap: true,
        tapAction: { [weak self] closure in
          self?.tapAction(closure: closure)
        },
        completion: { [weak self] isSuccess in
          self?.completion(isSuccess: isSuccess)
        })
    
    viewInput?.update(with: configuration)
  }
  
  func initialConfiguration(model: SendTransactionViewModel) -> ModalContentViewController.Configuration {
    let configuration = SendConfirmationModalConfigurationBuilder
      .configuration(
        title: model.title,
        image: .with(image: model.image),
        recipientName: model.recipientName,
        recipientAddress: model.recipientAddress,
        amount: model.amountToken,
        fiatAmount: .loading,
        fee: .loading,
        fiatFee: .loading,
        comment: model.comment,
        showActivity: true,
        showActivityOnTap: false)
    
    return configuration
  }
  
  func prepareTransaction() async throws -> String {
    return try await sendController.prepareSendTransaction(
      itemTransferModel: itemTransferModel,
      recipientAddress: address,
      comment: comment)
  }
  
  func tapAction(closure: @escaping (Bool) -> Void) {
    
  }
  
  func completion(isSuccess: Bool) {
    
  }
}
