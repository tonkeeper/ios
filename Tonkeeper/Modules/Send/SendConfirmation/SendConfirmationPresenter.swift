//
//  SendConfirmationSendConfirmationPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 03/06/2023.
//

import Foundation
import WalletCoreKeeper
import BigInt

final class SendConfirmationPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendConfirmationViewInput?
  weak var output: SendConfirmationModuleOutput?
  
  // MARK: - Dependencies
  
  private let sendController: SendController
  
  // MARK: - State

  init(sendController: SendController) {
    self.sendController = sendController
  }
}

// MARK: - SendConfirmationPresenterIntput

extension SendConfirmationPresenter: SendConfirmationPresenterInput {
  func viewDidLoad() {
    sendController.prepareTransaction()
  }
  
  func didTapCloseButton() {
    output?.sendConfirmationModuleDidTapCloseButton()
  }
}

// MARK: - SendConfirmationModuleInput

extension SendConfirmationPresenter: SendConfirmationModuleInput {}

extension SendConfirmationPresenter: SendControllerDelegate {
  func sendControllerDidStartLoadInitialData(_ sendController: WalletCoreKeeper.SendController) {}
  
  func sendController(_ sendController: SendController, didUpdate model: SendTransactionViewModel) {
    let configuration = mapToConfiguration(model: model)
    viewInput?.update(with: configuration)
  }
  
  func sendControllerFailed(_ sendController: SendController, error: SendControllerError) {
    switch error {
    case .failedToPrepareTransaction:
      viewInput?.showError(errorTitle: .failedToPrepareTransactionErrorTitle)
      output?.sendConfirmationModuleDidFailedToPrepareTransaction()
    case .failedToEmulateTransaction:
      viewInput?.showError(errorTitle: .failedToCalculateFeeErrorTitle)
    case .failedToSendTransaction:
      viewInput?.showError(errorTitle: .failedToSendTransactionErrorTitle)
    }
  }
}

// MARK: - Private

private extension SendConfirmationPresenter {
  func mapToConfiguration(model: SendTransactionViewModel) -> ModalContentViewController.Configuration {
    switch model {
    case .token(let sendTokenModel):
      return mapSendTokenModelToConfiguration(model: sendTokenModel)
    case .nft(let sendNFTModel):
      return mapSendNFTModelToConfiguration(model: sendNFTModel)
    }
  }
  
  func mapSendTokenModelToConfiguration(model: SendTransactionViewModel.SendTokenModel) -> ModalContentViewController.Configuration {
    let fiatAmount: ModalContentViewController.Configuration.ListItem.RightItem<String?>
    switch model.amountFiat {
    case .loading: fiatAmount = .loading
    case .value(let value): fiatAmount = .value(value)
    }
    
    let fee: ModalContentViewController.Configuration.ListItem.RightItem<String?>
    switch model.feeTon {
    case .loading: fee = .loading
    case .value(let value): fee = .value(value ?? "?")
    }
    
    let feeFiat: ModalContentViewController.Configuration.ListItem.RightItem<String?>
    switch model.feeFiat {
    case .loading: feeFiat = .loading
    case .value(let value):feeFiat = .value(value)
    }
    
    let configuration = SendConfirmationModalConfigurationBuilder
      .configuration(
        title: model.title,
        image: .with(image: model.image),
        recipientName: model.recipientName,
        recipientAddress: model.recipientAddress,
        amount: model.amountToken,
        fiatAmount: fiatAmount,
        fee: fee,
        fiatFee: feeFiat,
        comment: model.comment,
        showActivity: false,
        showActivityOnTap: true,
        tapAction: tapAction,
        completion: completion)
    
    return configuration
  }
  
  func mapSendNFTModelToConfiguration(model: SendTransactionViewModel.SendNFTModel) -> ModalContentViewController.Configuration {
    let fee: ModalContentViewController.Configuration.ListItem.RightItem<String?>
    switch model.feeTon {
    case .loading:
      fee = .loading
    case .value(let value):
      fee = .value(value ?? "?")
    }
    
    let feeFiat: ModalContentViewController.Configuration.ListItem.RightItem<String?>
    switch model.feeFiat {
    case .loading:
      feeFiat = .loading
    case .value(let value):
      feeFiat = .value(value)
    }
    
    let configuration = SendConfirmationModalConfigurationBuilder
      .nftSendConfiguration(
        title: model.title,
        description: model.description,
        image: .with(image: model.image),
        recipientName: model.recipientName,
        recipientAddress: model.recipientAddress,
        fee: fee,
        fiatFee: feeFiat,
        comment: model.comment,
        nftId: model.nftId,
        nftCollectionId: model.nftCollectionId,
        showActivity: false,
        showActivityOnTap: true,
        tapAction: tapAction,
        completion: completion)
    
    return configuration
  }
  
  func tapAction(closure: @escaping (Bool) -> Void) {
    Task {
      guard let isConfirmed = await output?.sendConfirmationModuleConfirmation(),
            isConfirmed else {
        await MainActor.run {
          closure(false)
        }
        return
      }
      do {
        try await self.sendController.sendTransaction()
        await MainActor.run {
          closure(true)
          // TODO: Implement without NotificationCenter
          NotificationCenter.default.post(Notification(name: Notification.Name("DidSendTransaction")))
        }
      } catch {
        await MainActor.run {
          closure(false)
        }
      }
    }
  }

  func completion(isSuccess: Bool) {
    guard isSuccess else { return }
    output?.sendConfirmationModuleDidFinish()
  }
}


private extension String {
  static let failedToPrepareTransactionErrorTitle = "Failed to prepare transaction"
  static let failedToCalculateFeeErrorTitle = "Failed to calculate fee"
  static let failedToSendTransactionErrorTitle = "Failed"
}

