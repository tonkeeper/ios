//
//  SendAmountSendAmountPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

final class SendAmountPresenter {
  
  struct CurrencyPair {
    struct CurrencyAmount {
      let currency: Currency
      var amount: Decimal?
    }
    
    enum Primary {
      case first
      case second
    }
    
    var firstCurrency: CurrencyAmount
    var secondCurrency: CurrencyAmount
    var exchangeRate: Decimal
    var primary: Primary
    
    mutating func updateFirstCurrencyAmount(_ amount: Decimal?) {
      firstCurrency.amount = amount
      if let amount = amount {
        secondCurrency.amount = amount * exchangeRate
      }
    }
    
    mutating func updateAmount(_ amount: Decimal?) {
      switch primary {
      case .first:
        firstCurrency.amount = amount
        if let amount = amount {
          secondCurrency.amount = amount * exchangeRate
        }
      case .second:
        secondCurrency.amount = amount
        if let amount = amount {
          firstCurrency.amount = amount / exchangeRate
        }
      }
    }
    
    mutating func toggleActive() {
      switch primary {
      case .first:
        self.primary = .second
      case .second:
        self.primary = .first
      }
    }
    
    var activeCurrency: CurrencyAmount {
      switch primary {
      case .first:
        return firstCurrency
      case .second:
        return secondCurrency
      }
    }
    
    var inactiveCurrency: CurrencyAmount {
      switch primary {
      case .first:
        return secondCurrency
      case .second:
        return firstCurrency
      }
    }
  }

  // MARK: - Module
  
  weak var viewInput: SendAmountViewInput?
  weak var output: SendAmountModuleOutput?
  
  // MARK: - State
  
  private var currencyPair = CurrencyPair(firstCurrency: .init(currency: CryptoCurrency.ton, amount: nil),
                                          secondCurrency: .init(currency: FiatCurrency.usd, amount: nil),
                                          exchangeRate: 1.74,
                                          primary: .first)
  private var wallet = CurrencyWallet(currency: CryptoCurrency.ton, balance: 0)
  private var isMax = false
  
  // MARK: - Dependencies

  private let primaryCurrencyFormatter: NumberFormatter
  private let secondaryCurrencyFormatter: NumberFormatter
  private let inputCurrencyFormatter: NumberFormatter
  
  let textFieldFormatController: TextFieldFormatController
  
  // MARK: - Init
  
  init(primaryCurrencyFormatter: NumberFormatter,
       secondaryCurrencyFormatter: NumberFormatter,
       inputCurrencyFormatter: NumberFormatter) {
    self.primaryCurrencyFormatter = primaryCurrencyFormatter
    self.secondaryCurrencyFormatter = secondaryCurrencyFormatter
    self.inputCurrencyFormatter = inputCurrencyFormatter
    self.textFieldFormatController = .init(numberFormatter: inputCurrencyFormatter)
  }
}

// MARK: - SendAmountPresenterIntput

extension SendAmountPresenter: SendAmountPresenterInput {
  func viewDidLoad() {
    setup()
    updateTitle()
    updateWalletBalance()
    updateAllCurrencyValues()
    updateRemaining()
  }
  
  func didTapCloseButton() {
    output?.sendAmountModuleDidTapCloseButton()
  }
  
  func didTapMaxButton() {
    isMax.toggle()
    updateMaxButton()
    updateAllCurrencyValues()
    updateRemaining()
  }
  
  func didChangeAmountText(text: String?) {
    let amount = primaryCurrencyFormatter.number(from: text ?? "0")
    currencyPair.updateAmount(amount?.decimalValue ?? 0)
    updateInactiveCurrencyValue()
    updateRemaining()
  }
  
  func didTapSwapButton() {
    currencyPair.toggleActive()
    primaryCurrencyFormatter.maximumFractionDigits = currencyPair.activeCurrency.currency.maximumFractionDigits
    inputCurrencyFormatter.maximumFractionDigits = currencyPair.activeCurrency.currency.maximumFractionDigits
    updateAllCurrencyValues()
    updateRemaining()
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
    secondaryCurrencyFormatter.maximumFractionDigits = 2
    secondaryCurrencyFormatter.roundingMode = .down
    inputCurrencyFormatter.roundingMode = .down
  }
  
  func updateTitle() {
    let model = SendAmountTitleView.Model(title: "Amount",
                                          subtitle: "To: EQCc…9ZLD")
    viewInput?.updateTitleView(model: model)
  }
  
  func updateAllCurrencyValues() {
    updateActiveCurrencyValue()
    updateInactiveCurrencyValue()
  }
  
  func updateInactiveCurrencyValue() {
    let inactiveCurrency = currencyPair.inactiveCurrency
    let inactiveAmountString = secondaryCurrencyFormatter.string(from: NSDecimalNumber(decimal: inactiveCurrency.amount ?? 0)) ?? ""
    let inactiveCurrencyCodeString = inactiveCurrency.currency.code
    
    viewInput?.updateSecondaryCurrency("\(inactiveAmountString) \(inactiveCurrencyCodeString)")
  }
  
  func updateActiveCurrencyValue() {
    let activeCurrency = currencyPair.activeCurrency
    let activeAmountString = primaryCurrencyFormatter.string(from: NSDecimalNumber(decimal: activeCurrency.amount ?? 0))
    let activeCurrencyCodeString = activeCurrency.currency.code
    
    viewInput?.updatePrimaryCurrency(activeAmountString, currencyCode: activeCurrencyCodeString)
  }
  
  func updateMaxButton() {
    if isMax {
      currencyPair.updateFirstCurrencyAmount(wallet.balance)
      viewInput?.selectMaxButton()
    } else {
      currencyPair.updateFirstCurrencyAmount(0)
      viewInput?.deselectMaxButton()
    }
  }
  
  func updateRemaining() {
    let remainAmount = wallet.balance - (currencyPair.firstCurrency.amount ?? 0)
    let resultString: NSAttributedString
    if remainAmount.isLess(than: 0) {
      resultString = "Insufficient balance"
        .attributed(with: .body2,
                    alignment: .right,
                    color: .Accent.red)
    } else {
      let amountString = secondaryCurrencyFormatter.string(from: NSDecimalNumber(decimal: remainAmount))
      resultString = "Remaining: \(amountString ?? "0") \(currencyPair.firstCurrency.currency.code)"
        .attributed(with: .body2,
                    alignment: .right,
                    color: .Text.secondary)
    }
    
    viewInput?.updateRemainingLabel(attributedString: resultString)
  }
  
  func updateWalletBalance() {
    wallet = .init(currency: currencyPair.firstCurrency.currency, balance: 666.6)
  }
}
