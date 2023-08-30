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
  
  // MARK: - State

  init(sendController: SendController) {
    self.sendController = sendController
  }
}

// MARK: - SendConfirmationPresenterIntput

extension SendConfirmationPresenter: SendConfirmationPresenterInput {
  func viewDidLoad() {
    updateInitialState()
    Task {
      await loadTransactionInformation()
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
    let model = sendController.initialSendTransactionModel()
    let configuration = mapToConfiguration(model: model, isInitial: true)
    viewInput?.update(with: configuration)
  }
  
  func loadTransactionInformation() async {
    do {
      let model = try await sendController.loadTransactionInformation()
      await MainActor.run {
        let configuration = mapToConfiguration(model: model, isInitial: false)
        viewInput?.update(with: configuration)
      }
    } catch {
      await MainActor.run {
        let model = sendController.initialSendTransactionModel()
        let configuration = mapToConfiguration(model: model, isInitial: false)
        viewInput?.update(with: configuration)
        viewInput?.showFailedToLoadFeeError(errorTitle: .failedToCalculateFeeErrorTitle)
      }
    }
  }
  
  func mapToConfiguration(model: SendTransactionViewModel,
                          isInitial: Bool) -> ModalContentViewController.Configuration {
    let fiatAmountItem: ModalContentViewController.Configuration.ListItem.RightItem<String?>
    if let fiatAmount = model.amountFiat {
      fiatAmountItem = .value(fiatAmount)
    } else {
      fiatAmountItem = isInitial ? .loading : .value(nil)
    }

    let configuration = SendConfirmationModalConfigurationBuilder
      .configuration(
        title: model.title,
        image: .with(image: model.image),
        recipientName: model.recipientName,
        recipientAddress: model.recipientAddress,
        amount: model.amountToken,
        fiatAmount: fiatAmountItem,
        fee: isInitial ? .loading : .value(model.feeTon ?? "?"),
        fiatFee: isInitial ? .loading : .value(model.feeFiat),
        comment: model.comment,
        showActivity: false,
        showActivityOnTap: true,
        tapAction: tapAction,
        completion: completion)

    return configuration
  }

  func tapAction(closure: @escaping (Bool) -> Void) {
    Task {
      do {
        try await self.sendController.sendTransaction()
        await MainActor.run {
          closure(true)
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
    output?.sendRecipientModuleDidFinish()
  }
}


private extension String {
  static let failedToCalculateFeeErrorTitle = "Failed to calculate fee"
}

