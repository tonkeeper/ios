import UIKit
import KeeperCore
import TKCore
import TKUIKit
import TKLocalize
import BigInt

protocol BuyAndSellViewModelOutput: AnyObject {
  var didContinue: ((TransactionAmountModel) -> Void)? { get set }
}

protocol BuyAndSellViewModel: AnyObject {
  var didUpdateModel: ((BuyAndSellView.Model) -> Void)? { get set }
  
  var amountTextFieldFormatter: SendAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmount(_ string: String)
  func didTapContinueButton()
  func didSelectSegment(at index: Int)
}

final class BuyAndSellViewModelImplementation: BuyAndSellViewModel, BuyAndSellViewModelOutput {
  
  // MARK: - BuyListModuleOutput
  
  var didContinue: ((TransactionAmountModel) -> Void)?
  
  // MARK: - BuyAndSellViewModel
  
  var didUpdateModel: ((BuyAndSellView.Model) -> Void)?
    
  private let buyListController: BuyListController
  private let tonRatesStore: TonRatesStore
  private let bigIntAmountFormatter: BigIntAmountFormatter
  
  init(
    buyListController: BuyListController,
    tonRatesStore: TonRatesStore,
    bigIntAmountFormatter: BigIntAmountFormatter
  ) {
    self.buyListController = buyListController
    self.tonRatesStore = tonRatesStore
    self.bigIntAmountFormatter = bigIntAmountFormatter
    self.amountDisclaimer = minBuyAmountString
  }
  
  // MARK: - State
  
  private var amountInput = ""
  private var convertedValue = ""
  private var amountDisclaimer = ""
  private var amount: BigUInt = 0
  private var mode: FiatMethodCategoryType = .buy
  private var isContinueEnabled: Bool = false
  
  func viewDidLoad() {
    amountDisclaimer = minBuyAmountString
    
    update()
    updateConverted()
    
    Task {
      await startObservations()
    }
  }
  
  private func startObservations() async {
    _ = await tonRatesStore.addEventObserver(self) { [weak self] observer, event in
      switch event {
      case .didUpdateRates:
        self?.updateConverted()
      }
    }
  }
  
  func didInputAmount(_ string: String) {
    let unformatted = amountTextFieldFormatter.unformatString(string) ?? ""
    let amount = buyListController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: TonInfo.fractionDigits)
    
    switch mode {
    case .buy:
      processBuyInput(unformatted, amount: amount.amount)
    case .sell:
      processSellInput(unformatted, amount: amount.amount)
    }
  }
  
  func didTapContinueButton() {
    let transactionModel = TransactionAmountModel(type: mode, amount: amount)
    didContinue?(transactionModel)
  }
  
  func didSelectSegment(at index: Int) {
    mode = FiatMethodCategoryType.allCases[index]
    didInputAmount(amountInput)
  }
  
  let amountTextFieldFormatter: SendAmountTextFieldFormatter = {
    let maximumIntegerDigits = 9
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = ","
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = maximumIntegerDigits
    numberFormatter.roundingMode = .down
    let amountInputFormatController = SendAmountTextFieldFormatter(
      currencyFormatter: numberFormatter,
      maximumIntegerDigits: maximumIntegerDigits
    )
    amountInputFormatController.shouldUpdateCursorLocation = false
    return amountInputFormatController
  }()
  
  private lazy var minBuyAmountString: String = {
    let formattedAmount = bigIntAmountFormatter.format(
      amount: BigUInt.minBuyAmount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2
    )
    return TKLocales.Buy.min_amount(formattedAmount)
  }()
  
  private lazy var minSellAmountString: String = {
    let formattedAmount = bigIntAmountFormatter.format(
      amount: BigUInt.minSellAmount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2
    )
    return TKLocales.Buy.min_amount(formattedAmount)
  }()
}

private extension BuyAndSellViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func updateConverted() {
    Task {
      let converted = await buyListController.convertTokenAmountToCurrency(amount)
      await MainActor.run {
        self.convertedValue = converted
        update()
      }
    }
  }
  
  func processBuyInput(_ unformattedInput: String, amount: BigUInt) {
    let exceedsMinimum = amount >= BigUInt.minBuyAmount
    
    amountDisclaimer = minBuyAmountString
    amountInput = unformattedInput
    self.amount = amount
    isContinueEnabled = exceedsMinimum
    updateConverted()
    update()
  }
  
  func processSellInput(_ unformattedInput: String, amount: BigUInt) {
    Task {
      let hasEnoughBalance = await buyListController.isAmountAvailableToSend(amount: amount, token: .ton)
      let exceedsMinimum = amount >= BigUInt.minSellAmount
      let disclaimer = hasEnoughBalance ? minSellAmountString : "Insufficient funds"
      
      await MainActor.run {
        amountDisclaimer = disclaimer
        amountInput = unformattedInput
        self.amount = amount
        isContinueEnabled = exceedsMinimum && hasEnoughBalance
        updateConverted()
        update()
      }
    }
  }
  
  func createModel() -> BuyAndSellView.Model {
    let amount = BuyAndSellView.Model.Amount(placeholder: "0", text: amountTextFieldFormatter.formatString(amountInput) ?? "")
    
    return BuyAndSellView.Model(
      isContinueButtonEnabled: isContinueEnabled,
      minAmountDisclaimer: amountDisclaimer,
      amount: amount,
      isConvertedAmountShown: !convertedValue.isEmpty,
      convertedAmount: convertedValue
    )
  }
}

private extension BigUInt {
  static var minBuyAmount = BigUInt(stringLiteral: "2500000000")
  static var minSellAmount = BigUInt(stringLiteral: "5000000000")
}
