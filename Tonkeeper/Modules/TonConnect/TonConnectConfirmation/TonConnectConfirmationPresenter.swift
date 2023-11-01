//
//  TonConnectConfirmationPresenter.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import Foundation
import WalletCore

final class TonConnectConfirmationPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TonConnectConfirmationViewInput?
  weak var output: TonConnectConfirmationModuleOutput?
  
  // MARK: - Dependencies
  
  private let model: TonConnectConfirmationModel
  private let transactionBuilder: ActivityListTransactionBuilder

  // MARK: - Init
  
  init(model: TonConnectConfirmationModel,
       transactionBuilder: ActivityListTransactionBuilder) {
    self.model = model
    self.transactionBuilder = transactionBuilder
  }
}

// MARK: - TonConnectConfirmationPresenterInput

extension TonConnectConfirmationPresenter: TonConnectConfirmationPresenterInput {
  func viewDidLoad() {
    updateContent()
  }
}

// MARK: - TonConnectConfirmationModuleInput

extension TonConnectConfirmationPresenter: TonConnectConfirmationModuleInput {}

// MARK: - Private

private extension TonConnectConfirmationPresenter {
  func updateContent() {
    guard let viewInput = viewInput else { return }
    
    var contentItems = [ModalCardViewController.Configuration.ContentItem]()
    if let contentItem = contentItem() {
      contentItems.append(.item(contentItem))
    }
    
    let actionBarItems: [ModalCardViewController.Configuration.Item] = [
      .buttonsRow(.init(buttons: [
        cancelButton(),
        confirmButton()
      ]), bottomSpacing: 16, itemSpacing: 8)
    ]
    let configuration = ModalCardViewController.Configuration(
      header: .init(items: []),
      content: .init(items: contentItems),
      actionBar: .init(items: actionBarItems)
    )
    viewInput.update(with: configuration)
  }
  
  func confirmButton() -> ModalCardViewController.Configuration.Button {
    ModalCardViewController.Configuration.Button.init(
      title: "Confirm",
      configuration: .primaryLarge,
      isEnabled: true,
      isActivity: false,
      tapAction: { [weak self] isActivityClosure, isSuccessClosure in
        guard let self = self else { return }
        isActivityClosure(true)
        Task {
          let isSuccess = try await self.handleConfirmButtonTap()
          await MainActor.run {
            isSuccessClosure(isSuccess)
          }
        }
      },
      completionAction: { [weak self] isSuccess in
        guard let self = self else { return }
        if isSuccess {
          self.output?.tonConnectConfirmationModuleDidFinish(self)
        } else {
          self.output?.tonConnectConfirmationModuleDidCancel(self)
        }
      })
  }
  
  func cancelButton() -> ModalCardViewController.Configuration.Button {
    ModalCardViewController.Configuration.Button.init(
      title: "Cancel",
      configuration: .secondaryLarge,
      isEnabled: true,
      isActivity: false,
      tapAction: { [weak self] isActivityClosure, isSuccessClosure in
        guard let self = self else { return }
        isActivityClosure(false)
        self.output?.tonConnectConfirmationModuleDidCancel(self)
      },
      completionAction: { [weak self] isSuccess in
        guard let self = self,
              isSuccess else { return }
        self.output?.tonConnectConfirmationModuleDidFinish(self)
      })
  }
  
  func contentItem() -> ModalCardViewController.Configuration.Item? {
    let model = TonConnectConfirmationContentView.Model(
      actionsModel: mapEventViewModel(model.event),
      feeModel: .init(title: "Network fee", fee: model.fee)
    )
    guard let view = viewInput?.getConfirmationContentView(model: model) else { return nil }
    return .customView(view, bottomSpacing: 16)
  }
  
  func mapEventViewModel(_ viewModel: ActivityEventViewModel) -> CompositionTransactionCellContentView.Model {
    let actions = viewModel.actions.map { action in
      return transactionBuilder.buildTransactionModel(
        type: action.eventType,
        subtitle: action.leftTopDescription,
        amount: action.amount,
        subamount: action.subamount,
        time: action.rightTopDescription,
        status: action.status,
        comment: action.comment,
        collectible: action.collectible
      )
    }
    return CompositionTransactionCellContentView.Model(transactionContentModels: actions)
  }
  
  func handleConfirmButtonTap() async throws -> Bool {
    guard let output = output else { return false }
    let isConfirmed = await output.tonConnectConfirmationModuleUserConfirmation(self)
    guard isConfirmed else { return false }
    do {
      try await self.output?.tonConnectConfirmationModuleDidConfirm(self)
      return true
    } catch {
      return false
    }
  }
}
