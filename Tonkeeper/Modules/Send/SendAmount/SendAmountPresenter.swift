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
  private let recipient: Recipient
  
  let amountInputFormatController: AmountInputFormatController
  let sendInputController: SendInputController
  
  // MARK: - Init
  
  init(inputCurrencyFormatter: NumberFormatter,
       sendInputController: SendInputController,
       recipient: Recipient) {
    self.inputCurrencyFormatter = inputCurrencyFormatter
    self.amountInputFormatController = AmountInputFormatController(currencyFormatter: inputCurrencyFormatter)
    self.sendInputController = sendInputController
    self.recipient = recipient
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
    sendInputController.didChangeInput(string: amountInputFormatController.unformatString(text))
  }
  
  func didTapSwapButton() {
    sendInputController.toggleActive()
  }
  
  func didTapSelectTokenButton() {
    let listModel = sendInputController.tokenListModel()
    let menuItems = listModel.tokens.enumerated().map {
      TKMenuItem(icon: .with(image: $0.element.icon),
                 leftTitle: $0.element.code,
                 rightTitle: $0.element.amount,
                 isSelected: $0.offset == listModel.selectedIndex)
    }
    viewInput?.showMenu(items: menuItems)
  }
  
  func didTapContinueButton() {
    guard let itemTransferModel = sendInputController.itemTransferModel else { return }
    output?.sendAmountModuleDidEnterAmount(itemTransferModel: itemTransferModel)
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
    let subtitle = NSMutableAttributedString(string: "", attributes: nil)
    if let name = recipient.domain {
      let nameString = "To: \(name)"
        .attributed(with: .body2,  alignment: .center, lineBreakMode: .byWordWrapping, color: .Text.secondary)
      let walletString = " \(recipient.address.shortString)"
        .attributed(with: .body2,  alignment: .center, lineBreakMode: .byClipping, color: .Text.tertiary)
      subtitle.append(nameString)
      subtitle.append(walletString)
    } else {
      let walletString = "To: \(recipient.address.shortString)"
        .attributed(with: .body2,  alignment: .center, lineBreakMode: .byClipping, color: .Text.secondary)
      subtitle.append(walletString)
    }
    let model = SendAmountTitleView.Model(title: "Amount",
                                          subtitle: subtitle)
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
