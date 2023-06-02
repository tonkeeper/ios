//
//  SendAmountSendAmountPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

final class SendAmountPresenter {
  
  struct State {
    enum Mode {
      case crypto
      case fiat
    }
    
    let wallet: CurrencyWallet
    let mode: Mode
    let isMax: Bool
    let cryptoValue: Decimal?
    let exchangeRate: Decimal
    
    var fiatAmount: Decimal? {
      guard let cryptoValue = cryptoValue else { return nil }
      return cryptoValue * exchangeRate
    }
    
    init(wallet: CurrencyWallet,
         mode: Mode,
         isMax: Bool,
         cryptoValue: Decimal?,
         exchangeRate: Decimal) {
      self.wallet = wallet
      self.mode = mode
      self.isMax = isMax
      self.cryptoValue = cryptoValue
      self.exchangeRate = exchangeRate
    }
    
    func update(withInput input: Decimal?) -> State {
      let cryptoValue: Decimal?
      switch mode {
      case .crypto:
        cryptoValue = input
      case .fiat:
        if let input = input {
          cryptoValue = input * exchangeRate
        } else {
          cryptoValue = nil
        }
      }
      return .init(wallet: wallet,
                   mode: mode,
                   isMax: isMax,
                   cryptoValue: cryptoValue,
                   exchangeRate: exchangeRate)
    }
    
    func toggleMax() -> State {
      let newIsMax = !isMax
      let value = newIsMax ? wallet.balance : 0
      return .init(wallet: wallet,
                   mode: mode,
                   isMax: newIsMax,
                   cryptoValue: value,
                   exchangeRate: exchangeRate)
    }
    
    func updateWalletBalance(_ balance: Decimal) -> State {
      .init(wallet: .init(currency: wallet.currency, balance: balance),
            mode: mode,
            isMax: isMax,
            cryptoValue: cryptoValue,
            exchangeRate: exchangeRate)
    }
  }
  
  // MARK: - Module
  
  weak var viewInput: SendAmountViewInput?
  weak var output: SendAmountModuleOutput?
  
  // MARK: - State
  
  private var state = State(wallet: .init(currency: CryptoCurrency.ton, balance: 0),
                            mode: .crypto,
                            isMax: false,
                            cryptoValue: nil,
                            exchangeRate: 2) {
    didSet { updateState() }
  }
  
  private var inputAmount: Decimal?
  
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
    updateWalletBalance()
    updateTitle()
    updateState()
  }
  
  func didTapCloseButton() {
    output?.sendAmountModuleDidTapCloseButton()
  }
  
  func didTapMaxButton() {
    state = state.toggleMax()
  }
  
  func didChangeAmountText(text: String?) {
    let amount = textFieldFormatController.getUnformattedNumber(text)?.decimalValue
    self.state = state.update(withInput: amount)
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
  
  func updateState() {
    updateDisplayValues()
    updateRemainingAmount()
    updateMaxButtonState()
  }
  
  func updateDisplayValues() {
    let topAmount: String?
    let topCurrencyCode: String?
    let bottomAmount: String?
    let bottomCurrencyCode: String?
    
    switch state.mode {
    case .crypto:
      if let cryptoValue = state.cryptoValue {
        topAmount = currencyFormatter.string(from: NSDecimalNumber(decimal: cryptoValue))
      } else {
        topAmount = nil
      }
      topCurrencyCode = state.wallet.currency.code
      
      bottomAmount = currencyFormatter.string(from: NSDecimalNumber(decimal: state.fiatAmount ?? 0))
      bottomCurrencyCode = FiatCurrency.usd.code
    case .fiat:
      if let fiatAmount = state.fiatAmount {
        topAmount = currencyFormatter.string(from: NSDecimalNumber(decimal: fiatAmount))
      } else {
        topAmount = nil
      }
      topCurrencyCode = FiatCurrency.usd.code
      
      bottomAmount = currencyFormatter.string(from: NSDecimalNumber(decimal: state.cryptoValue ?? 0))
      bottomCurrencyCode = state.wallet.currency.code
    }
    
    viewInput?.updateInputValue(topAmount)
    viewInput?.updateInputCurrencyCode(topCurrencyCode)
  }
  
  func updateRemainingAmount() {
    let amount =  state.wallet.balance - (state.cryptoValue ?? 0)
    let resultString: NSAttributedString
    if amount.isLess(than: 0) {
      resultString = "Insufficient balance"
        .attributed(with: .body2,
                    alignment: .right,
                    color: .Accent.red)
    } else {
      let amountString = currencyFormatter.string(from: NSDecimalNumber(decimal: amount))
      resultString = "Remaining: \(amountString ?? "0") \(state.wallet.currency.code)"
        .attributed(with: .body2,
                    alignment: .right,
                    color: .Text.secondary)
    }
    
    viewInput?.updateRemainingLabel(attributedString: resultString)
  }
  
  func updateMaxButtonState() {
    switch state.isMax {
    case true:
      viewInput?.selectMaxButton()
    case false:
      viewInput?.deselectMaxButton()
    }
  }
  
  func updateWalletBalance() {
    state = state.updateWalletBalance(666.6666)
  }
}
