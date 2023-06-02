//
//  SendAmountSendAmountPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

final class SendAmountPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendAmountViewInput?
  weak var output: SendAmountModuleOutput?
  
  // MARK: - State
  
  private var isMaxToggled = false
  private var remainingAmount: Decimal = 666.666666
  
  // MARK: - Dependencies

  private let currencyFormatter: NumberFormatter
  
  let textFieldFormatController: TextFieldFormatController
  
  // MARK: - Init
  
  init(currencyFormatter: NumberFormatter) {
    self.currencyFormatter = currencyFormatter
    self.textFieldFormatController = .init(numberFormatter: currencyFormatter)
  }
}

// MARK: - SendAmountPresenterIntput

extension SendAmountPresenter: SendAmountPresenterInput {
  func viewDidLoad() {
    updateTitle()
    updateRemainingAmount()
  }
  
  func didTapCloseButton() {
    output?.sendAmountModuleDidTapCloseButton()
  }
  
  func didTapMaxButton() {
    isMaxToggled.toggle()
    isMaxToggled
    ? viewInput?.selectMaxButton()
    : viewInput?.deselectMaxButton()
    updateRemainingAmount()
  }
  
  func didChangeAmountText(text: String?) {
    let amount = textFieldFormatController.getUnformattedNumber(text) ?? NSNumber(value: 0)
  }
}

// MARK: - SendAmountModuleInput

extension SendAmountPresenter: SendAmountModuleInput {}

// MARK: - Private

private extension SendAmountPresenter {
  func updateTitle() {
    let model = SendAmountTitleView.Model(title: "Amount",
                                          subtitle: "To: EQCc…9ZLD")
    viewInput?.updateTitleView(model: model)
  }
  
  func updateRemainingAmount() {
    let amount: Decimal = isMaxToggled ? 0 : remainingAmount
    let formattedRemainingAmount = currencyFormatter.string(from: NSDecimalNumber(decimal: amount))
    let string = "Remaining: \(formattedRemainingAmount ?? "0") TON"
    viewInput?.updateRemainingLabel(string: string)
  }
}
