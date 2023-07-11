//
//  SendAmountSendAmountPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation
import UIKit
import WalletCore
import TonSwift
import BigInt

final class SendAmountPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendAmountViewInput?
  weak var output: SendAmountModuleOutput?
  
  // MARK: - State
  
  private var isMax = false
  
  // MARK: - Dependencies

  private let inputCurrencyFormatter: NumberFormatter
  private let address: String
  private let comment: String?
  
  let amountInputFormatController: AmountInputFormatController
  let sendInputController: SendInputController
  let sendController: SendController
  
  // MARK: - Init
  
  init(inputCurrencyFormatter: NumberFormatter,
       sendInputController: SendInputController,
       sendController: SendController,
       address: String,
       comment: String?) {
    self.inputCurrencyFormatter = inputCurrencyFormatter
    self.amountInputFormatController = AmountInputFormatController(currencyFormatter: inputCurrencyFormatter)
    self.sendInputController = sendInputController
    self.sendController = sendController
    self.address = address
    self.comment = comment
  }
}

// MARK: - SendAmountPresenterIntput

extension SendAmountPresenter: SendAmountPresenterInput {
  func viewDidLoad() {
    setup()
    updateTitle()
    sendInputController.setInitialState()
  }
  
  func didTapCloseButton() {
    output?.sendAmountModuleDidTapCloseButton()
  }
  
  func didTapMaxButton() {
    isMax.toggle()
    updateMaxButton()
  }
  
  func didChangeAmountText(text: String?) {
    sendInputController.didChangeInput(string: amountInputFormatController.getUnformattedString(text))
  }
  
  func didTapSwapButton() {
    sendInputController.toggleActive()
  }
  
  func didTapSelectTokenButton() {
    let listModel = sendInputController.tokenListModel()
    let menuItems = listModel.tokens.enumerated().map {
      TKMenuItem(icon: .image(nil, backgroundColor: nil),
                 leftTitle: $0.element.code,
                 rightTitle: $0.element.amount,
                 isSelected: $0.offset == listModel.selectedIndex)
    }
    viewInput?.showMenu(items: menuItems)
  }
  
  func didTapContinueButton() {
    viewInput?.showActivity()
    Task {
      do {
        let transactionBoc = try await sendController.prepareTransaction(
          value: sendInputController.tokenAmount,
          address: address,
          comment: comment
        )
        let transactionModel = try await sendController.loadTransactionInformation(transactionBoc: transactionBoc)
        Task { @MainActor in
          viewInput?.hideActivity()
          output?.sendAmountModuleDidPrepareTransaction(transactionModel)
        }
      } catch {
        Task { @MainActor in
          viewInput?.hideActivity()
        }
      }
    }
  }
  
  func didSelectToken(at index: Int) {
    try? sendInputController.didSelectToken(at: index)
  }
}

// MARK: - SendAmountModuleInput

extension SendAmountPresenter: SendAmountModuleInput {}

// MARK: - Private

private extension SendAmountPresenter {
  func setup() {
    inputCurrencyFormatter.maximumFractionDigits = 9
    inputCurrencyFormatter.roundingMode = .down
    
    sendInputController.didUpdateInactiveAmount = { [weak self] value in
      self?.viewInput?.updateSecondaryCurrency(value)
    }
    
    sendInputController.didUpdateActiveAmount = { [weak self] value, code in
      self?.viewInput?.updatePrimaryCurrency(value, currencyCode: code)
    }
    
    sendInputController.didChangeInputMaximumFractionLength = { [weak self] length in
      self?.inputCurrencyFormatter.maximumFractionDigits = length
    }
    
    sendInputController.didUpdateAvailableBalance = { [weak self] value, isInsufficient in
      let color: UIColor = isInsufficient ? .Accent.red : .Text.secondary
      let string = value.attributed(with: .body2,
                                    alignment: .right,
                                    color: color)
      self?.viewInput?.updateRemainingLabel(attributedString: string)
    }
    
    sendInputController.didUpdateContinueButtonAvailability = { [weak self] isAvailable in
      self?.viewInput?.updateContinueButtonAvailability(isAvailable)
    }
    
    sendInputController.didChangeToken = { [weak self] tokenCode in
      if let tokenCode = tokenCode {
        self?.viewInput?.showTokenSelectionButton(tokenCode)
      } else {
        self?.viewInput?.hideTokenSelectionButton()
      }
    }
  }
  
  func updateTitle() {
    let shortAddress = (try? Address.parse(address).shortString) ?? ""
    let model = SendAmountTitleView.Model(title: "Amount",
                                          subtitle: "To: \(shortAddress)")
    viewInput?.updateTitleView(model: model)
  }
  
  func updateMaxButton() {
    try? sendInputController.toggleMax()
    if sendInputController.isMax {
      viewInput?.selectMaxButton()
    } else {
      viewInput?.deselectMaxButton()
    }
  }
}
