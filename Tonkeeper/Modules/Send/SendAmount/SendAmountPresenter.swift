//
//  SendAmountSendAmountPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation
import UIKit
import WalletCore

final class SendAmountPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendAmountViewInput?
  weak var output: SendAmountModuleOutput?
  
  // MARK: - State
  
  private var isMax = false
  
  // MARK: - Dependencies

  private let inputCurrencyFormatter: NumberFormatter
  
  let amountInputFormatController: AmountInputFormatController
  let sendInputController: SendInputController
  
  // MARK: - Init
  
  init(inputCurrencyFormatter: NumberFormatter,
       sendInputController: SendInputController) {
    self.inputCurrencyFormatter = inputCurrencyFormatter
    self.amountInputFormatController = AmountInputFormatController(currencyFormatter: inputCurrencyFormatter)
    self.sendInputController = sendInputController
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
  
  func didTapContinueButton() {
    output?.sendAmountModuleDidTapContinueButton()
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
  }
  
  func updateTitle() {
    let model = SendAmountTitleView.Model(title: "Amount",
                                          subtitle: "To: EQCc…9ZLD")
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
