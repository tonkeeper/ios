import UIKit
import KeeperCore
import BigInt

protocol BuySellAmountModuleOutput: AnyObject {
  var didUpdateIsContinueEnable: ((Bool) -> Void)? { get set }
  var didFinish: ((FiatMethods, [BuySellItemModel], String, BuySellRateItemsResponse, Double, Bool) -> Void)? { get set }
  var onOpenCurrencyPicker: (([FiatMethodLayout], String) -> Void)? { get set }
}

protocol BuySellAmountModuleInput: AnyObject {
  func setToken(token: Token)
  func updateCurrency(to item: String)
}

protocol BuySellAmountViewModel: AnyObject {
  
  var didUpdateConvertedValue: ((String) -> Void)? { get set }
  var didUpdateInputValue: ((String?) -> Void)? { get set }
  var didUpdateInputSymbol: ((String?) -> Void)? { get set }
  var didUpdateMaximumFractionDigits: ((Int) -> Void)? { get set }
  var didUpdateIsTokenPickerAvailable: ((Bool) -> Void)? { get set }
  var didUpdateRemaining: ((NSAttributedString) -> Void)? { get set }
  var didUpdateCurrency: ((Currency) -> Void)? { get set }
  func openCurrencyPicker()
  var onUpdateMinAmountLabel: ((BuySellRateItemsResponse?) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
  func didEditInput(_ input: String?)
  func toggleInputMode()
  func finish(isBuying: Bool, amount: Double)
  func format(amount: Int64) -> String
  func refreshMinAmount()
  var currencies: [FiatMethodLayout] { get set }
}

final class BuySellAmountViewModelImplementation: BuySellAmountViewModel,
                                                  BuySellAmountModuleOutput,
                                                  BuySellAmountModuleInput {
  
  // MARK: - SendAmountModuleOutput
  
  var didUpdateIsContinueEnable: ((Bool) -> Void)?
  var didFinish: ((FiatMethods, [BuySellItemModel], String, BuySellRateItemsResponse, Double, Bool) -> Void)?
  var onOpenCurrencyPicker: (([FiatMethodLayout], String) -> Void)?
  var onUpdateMinAmountLabel: ((BuySellRateItemsResponse?) -> Void)?
  
  // MARK: - SendAmountModuleInput
  
  func finish(isBuying: Bool, amount: Double) {
    guard let rates = buySellAmountController.rates else {
      return
    }
    guard let fiatMethods = buySellAmountController.fiatMethods else {
      return
    }
    didFinish?(fiatMethods, isBuying ? methods[0] : methods[1], selectedCurrency.code, rates, amount, isBuying)
  }
  
  func setToken(token: Token) {
    buySellAmountController.setToken(token)
  }
  
  func updateCurrency(to item: String) {
    buySellAmountController.rates = nil
    Task {
      self.selectedCurrency = await buySellAmountController.getActiveCurrency()
      await MainActor.run {
        /*if let it = currencies.first(where: { it in
          it.countryCode == selectedCurrency
        }) {
          didUpdateCurrency?(it)
        }*/
        didUpdateCurrency?(self.selectedCurrency)
      }
      await buySellAmountController.updateBuySellRates()
      await MainActor.run {
        onUpdateMinAmountLabel?(buySellAmountController.rates)
      }
    }
  }
  
  func format(amount: Int64) -> String {
    return buySellAmountController.amountFormatter.formatAmount(BigUInt(amount), fractionDigits: 9, maximumFractionDigits: 9)
  }

  func refreshMinAmount() {
    onUpdateMinAmountLabel?(buySellAmountController.rates)
  }

  // MARK: - SendAmountViewModel
  
  var didUpdateConvertedValue: ((String) -> Void)?
  var didUpdateInputValue: ((String?) -> Void)?
  var didUpdateInputSymbol: ((String?) -> Void)?
  var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  var didUpdateIsTokenPickerAvailable: ((Bool) -> Void)?
  var didUpdateRemaining: ((NSAttributedString) -> Void)?
  var didUpdateCurrency: ((Currency) -> Void)?
  var methods = [[BuySellItemModel]]()
  var currencies: [FiatMethodLayout] = []
  var selectedCurrency: Currency = .USD
  
  func viewDidLoad() {
    buySellAmountController.didUpdateConvertedValue = { [weak self] value in
      self?.didUpdateConvertedValue?(value)
    }
    
    buySellAmountController.didUpdateInputValue = { [weak self] value in
      self?.didUpdateInputValue?(value)
    }
    
    buySellAmountController.didUpdateInputSymbol = { [weak self] symbol in
      self?.didUpdateInputSymbol?(symbol)
    }
    
    buySellAmountController.didUpdateMaximumFractionDigits = { [weak self] fractionDigits in
      self?.didUpdateMaximumFractionDigits?(fractionDigits)
    }
    
    buySellAmountController.didUpdateIsTokenPickerAvailable = { [weak self] in
      self?.didUpdateIsTokenPickerAvailable?($0)
    }
    
    buySellAmountController.didUpdateIsContinueEnabled = { [weak self] in
      self?.isContinueEnabled = $0
    }
    
    buySellAmountController.didUpdateRemaining = { [weak self] remaining in
      switch remaining {
      case .remaining(let value):
        self?.didUpdateRemaining?(
          "Remaining: \(value)".withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
          )
        )
      case .insufficient:
        self?.didUpdateRemaining?(
          "Insufficient balance".withTextStyle(
            .body2,
            color: .Accent.red,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
          )
        )
      }
    }
    
    buySellAmountController.didUpdateMethods = { [weak self] (methods, currencies) in
      guard let self else { return }
      self.methods = methods
      self.currencies = currencies
    }
    
    buySellAmountController.start()
    updateCurrency(to: "")
  }
  
  func viewDidAppear() {
    didUpdateIsContinueEnable?(isContinueEnabled)
  }
  
  func viewWillDisappear() {
    didUpdateIsContinueEnable?(isContinueEnabled)
  }
  
  func didEditInput(_ input: String?) {
    buySellAmountController.setInput(input ?? "")
  }
  
  func toggleInputMode() {
    buySellAmountController.toggleMode()
  }
  
  func toggleMax() {
    buySellAmountController.toggleMax()
  }
  
  func openCurrencyPicker() {
    onOpenCurrencyPicker?(currencies, "")
  }
  
  // MARK: - State
  
  private var isContinueEnabled: Bool = false {
    didSet {
      didUpdateIsContinueEnable?(isContinueEnabled)
    }
  }
  
  // MARK: - Dependencies
  
  private let buySellAmountController: BuySellAmountController
  
  // MARK: - Init
  
  init(buySellAmountController: BuySellAmountController) {
    self.buySellAmountController = buySellAmountController
  }
}
