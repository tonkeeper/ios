import UIKit
import KeeperCore
import TKCore
import BigInt

struct BuySellItem {
  var token: Token
  var amount: BigUInt
}

protocol BuySellModuleOutput: AnyObject {
//  var didContinueBuy: ((BuyModel) -> Void)? { get set }
}

protocol BuySellModuleInput: AnyObject {
  
}

protocol BuySellViewModel: AnyObject {
  var didUpdateModel: ((BuySellModel) -> Void)? { get set }
  
  var buySellAmountTextFieldFormatter: BuySellAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmount(_ string: String)
}

struct BuySellModel {
  struct Amount {
    struct Token {
      let title: String
    }
    
    let text: String
    let fractionDigits: Int
    let token: Token
  }

  struct Button {
    let title: String
    let isEnabled: Bool
    let isActivity: Bool
    let action: (() -> Void)
  }
  
  struct Balance {
    let converted: String
    let currency: Currency
  }
  
  let amount: Amount?
  let balance: Balance
  let button: Button
}

final class BuySellViewModelImplementation: BuySellViewModel, BuySellModuleOutput, BuySellModuleInput {
  
  // MARK: - BuySellModelModuleOutput
  
  var didContinueSend: ((SendModel) -> Void)?
  var didTapPicker: ((Wallet, Token) -> Void)?
  var didTapScan: (() -> Void)?
  
  // MARK: - BuySellModelModuleInput
  
  var didUpdateModel: ((BuySellModel) -> Void)?
  
  // MARK: - BuySellModelViewModel
  
  func viewDidLoad() {
    update()
  }
  
  func didInputAmount(_ string: String) {
    Task {
      guard string != amountInput else { return }
      let unformatted = self.buySellAmountTextFieldFormatter.unformatString(string) ?? ""
      let amount = buySellController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: tokenFractionalDigits(token: .ton))
//      let isAmountValid = await buySellController.isAmountAvailableToBuySell(amount: amount.amount, token: token) && !amount.amount.isZero
      
      await MainActor.run {
        self.amountInput = unformatted
        self.buySellItem.amount = amount.amount
        updateConverted()
        update()
      }
    }
  }
  
  // MARK: - State
  
  private var amountInput = "0"
  private var convertedValue = "0"
  private var currency: Currency = .USD
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  private var isAmountValid: Bool = false {
    didSet {
      guard isAmountValid != oldValue else { return }
      update()
    }
  }
  
  private var isContinueEnabled: Bool = false {
    didSet {
      guard isContinueEnabled != oldValue else { return }
      update()
    }
  }
  
  // MARK: - Formatters
  
  let buySellAmountTextFieldFormatter: BuySellAmountTextFieldFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.groupingSeparator = " "
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    let buySellInputFormatController = BuySellAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
    return buySellInputFormatController
  }()
  
  // MARK: - Dependencies
  
  private let imageLoader = ImageLoader()
  private let buySellController: BuySellController
  private var buySellItem: BuySellItem
  
  // MARK: - Init
  
  init(buySellController: BuySellController, appSettings: AppSettings, buySellItem: BuySellItem) {
    self.buySellController = buySellController
    self.buySellItem = buySellItem
    self.buySellAmountTextFieldFormatter.maximumFractionDigits = tokenFractionalDigits(token: buySellItem.token)
  }
}

private extension BuySellViewModelImplementation {
  func createModel() -> BuySellModel {
    return BuySellModel(
      amount: createAmountModel(token: .ton),
      balance: BuySellModel.Balance(converted: "\(convertedValue)", currency: currency),
      button: BuySellModel.Button(
          title: "Continue",
          isEnabled: !isResolving && isContinueEnable,
          isActivity: isResolving,
          action: { //[weak self] in
//            guard let self else { return }
//            let buyModel = BuyModel()
//            didContinueBuy?(buyModel)
          }
        )
      )
  }
    
  func createAmountModel(token: Token) -> BuySellModel.Amount {
    return BuySellModel.Amount(
      text: buySellAmountTextFieldFormatter.formatString(amountInput) ?? "",
      fractionDigits: tokenFractionalDigits(token: token),
      token: createTokenModel(token: token)
    )
  }
  
  func createTokenModel(token: Token) -> BuySellModel.Amount.Token {
    let title: String
    switch token {
    case .ton:
      title = "TON"
    case .jetton(let item):
      title = item.jettonInfo.symbol ?? ""
    }
    
    return BuySellModel.Amount.Token(title: title)
  }
  
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func updateConverted() {
    Task {
      let token = buySellItem.token
      let amount = buySellItem.amount
      
      let currency = await buySellController.getActiveCurrency()
      let convertedValue = await buySellController.convertTokenAmountToCurrency(token: token, amount, currency: currency)
      await MainActor.run {
        self.convertedValue = convertedValue
        self.currency = currency
        update()
      }
    }
  }
  
  var isContinueEnable: Bool {
    return true
  }

  func tokenFractionalDigits(token: Token) -> Int {
    let fractionDigits: Int
    switch token {
    case .ton:
      fractionDigits = TonInfo.fractionDigits
    case .jetton(let jettonItem):
      fractionDigits = jettonItem.jettonInfo.fractionDigits
    }
    return fractionDigits
  }
}
