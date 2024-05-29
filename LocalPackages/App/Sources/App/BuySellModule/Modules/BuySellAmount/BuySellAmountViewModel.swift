import UIKit
import KeeperCore
import BigInt

protocol BuySellAmountModuleOutput: AnyObject {
  var didUpdateIsContinueEnable: ((Bool) -> Void)? { get set }
  var didFinish: ((Token, BigUInt) -> Void)? { get set }
  var didTapTokenPicker: ((Wallet, Token) -> Void)? { get set }
  var onOpenCurrencyPicker: (([FiatMethodLayout], String) -> Void)? { get set }
}

protocol BuySellAmountModuleInput: AnyObject {
  func finish()
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
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
  func didEditInput(_ input: String?)
  func toggleInputMode()
  func toggleMax()
  func didTapTokenPickerButton()
  var currencies: [FiatMethodLayout] { get set }
}

final class BuySellAmountViewModelImplementation: BuySellAmountViewModel,
                                                  BuySellAmountModuleOutput,
                                                  BuySellAmountModuleInput {
  
  // MARK: - SendAmountModuleOutput
  
  var didUpdateIsContinueEnable: ((Bool) -> Void)?
  var didFinish: ((Token, BigUInt) -> Void)?
  var didTapTokenPicker: ((Wallet, Token) -> Void)?
  var onOpenCurrencyPicker: (([FiatMethodLayout], String) -> Void)?
  
  // MARK: - SendAmountModuleInput
  
  func finish() {
    didFinish?(buySellAmountController.getToken(), buySellAmountController.getTokenAmount())
  }
  
  func setToken(token: Token) {
    buySellAmountController.setToken(token)
  }
  
  func updateCurrency(to item: String) {
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
    }
  }
  
  // MARK: - SendAmountViewModel
  
  var didUpdateConvertedValue: ((String) -> Void)?
  var didUpdateInputValue: ((String?) -> Void)?
  var didUpdateInputSymbol: ((String?) -> Void)?
  var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  var didUpdateIsTokenPickerAvailable: ((Bool) -> Void)?
  var didUpdateRemaining: ((NSAttributedString) -> Void)?
  var didUpdateCurrency: ((Currency) -> Void)?
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
      //self.methods = methods
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
  
  func didTapTokenPickerButton() {
    didTapTokenPicker?(buySellAmountController.wallet, buySellAmountController.token)
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
