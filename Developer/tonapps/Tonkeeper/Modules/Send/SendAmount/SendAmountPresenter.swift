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
  
  private var numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "TON"
    formatter.maximumFractionDigits = 10
    return formatter
  }()
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
    let formattedRemainingAmount = numberFormatter.string(from: NSDecimalNumber(decimal: amount))
    let string = "Remaining: \(formattedRemainingAmount ?? "0 TON")"
    viewInput?.updateRemainingLabel(string: string)
  }
}
