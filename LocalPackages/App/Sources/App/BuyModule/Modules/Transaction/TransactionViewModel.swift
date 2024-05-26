import UIKit
import KeeperCore
import TKCore
import TKUIKit
import TKLocalize
import BigInt

protocol TransactionViewModelOutput: AnyObject {
  var didContinue: ((TransactionItem) -> Void)? { get set }
}

protocol TransactionViewModel: AnyObject {
  var didUpdateModel: ((TransactionView.Model) -> Void)? { get set }
  
  var sendAmountTextFieldFormatter: SendAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputPayAmount(_ string: String)
  func didInputGetAmount(_ string: String)
  func didTapContinueButton()
}

final class TransactionViewModelImplementation: TransactionViewModel, TransactionViewModelOutput {
  
  // MARK: - TransactionViewModelOutput
  
  var didContinue: ((TransactionItem) -> Void)?
  
  // MARK: - TransactionViewModel
  
  var didUpdateModel: ((TransactionView.Model) -> Void)?
  
  // MARK: - State
  
  private let buySellItem: BuySellItemModel
  private let transactionModel: TransactionAmountModel
  
  private var payAmountInput = ""
  private var isPayAmountValid: Bool = false
  
  private var getAmountInput = ""
  private var isGetAmountValid: Bool = false
  
  private var validationErrorMessage: String? = nil
  
  private let inputValidator: BuySellInputValidator
  private let exchangeConverter: ExchangeConfirmationConverter
  private let currencyRateFormatter: CurrencyToTONFormatter
  private let currency: Currency
  
  init(
    buySellItem: BuySellItemModel,
    transactionModel: TransactionAmountModel,
    currency: Currency,
    exchangeConverter: ExchangeConfirmationConverter,
    currencyRateFormatter: CurrencyToTONFormatter,
    inputValidator: BuySellInputValidator
  ) {
    self.buySellItem = buySellItem
    self.transactionModel = transactionModel
    self.currency = currency
    self.exchangeConverter = exchangeConverter
    self.currencyRateFormatter = currencyRateFormatter
    self.inputValidator = inputValidator
  }
  
  func viewDidLoad() {
    switch transactionModel.type {
    case .buy:
      payAmountInput = exchangeConverter.fiatInput
      getAmountInput = exchangeConverter.tonInput
    case .sell:
      payAmountInput = exchangeConverter.tonInput
      getAmountInput = exchangeConverter.fiatInput
    }
    validate()
  }
  
  func didInputPayAmount(_ string: String) {
    guard string != payAmountInput else { return }
    let unformatted = sendAmountTextFieldFormatter.unformatString(string) ?? ""
    
    switch transactionModel.type {
    case .buy:
      exchangeConverter.updateFiatInput(unformatted)
      payAmountInput = unformatted
      getAmountInput = exchangeConverter.tonInput
    case .sell:
      exchangeConverter.updateTonInput(unformatted)
      payAmountInput = unformatted
      getAmountInput = exchangeConverter.fiatInput
    }
    validate()
  }
  
  func didInputGetAmount(_ string: String) {
    guard string != getAmountInput else { return }
    let unformatted = sendAmountTextFieldFormatter.unformatString(string) ?? ""
    
    switch transactionModel.type {
    case .buy:
      exchangeConverter.updateTonInput(unformatted)
      getAmountInput = unformatted
      payAmountInput = exchangeConverter.fiatInput
    case .sell:
      exchangeConverter.updateFiatInput(unformatted)
      payAmountInput = unformatted
      getAmountInput = exchangeConverter.tonInput
    }
    validate()
  }
  
  func validate() {
    switch transactionModel.type {
    case .buy:
      let result = inputValidator.validateBuy(amount: exchangeConverter.tonAmount)
      isPayAmountValid = true
      isGetAmountValid = result.isValid
      validationErrorMessage = result.message
      update()
    case .sell:
      Task {
        let result = await inputValidator.validateSell(amount: exchangeConverter.tonAmount)
        await MainActor.run {
          isPayAmountValid = result.isValid
          isGetAmountValid = true
          validationErrorMessage = result.message
          update()
        }
      }
    }
  }
  
  func didTapContinueButton() {
    let item = TransactionItem(buySellItem: buySellItem, amount: transactionModel.amount)
    didContinue?(item)
  }
  
  // MARK: - Formatters
  
  let sendAmountTextFieldFormatter: SendAmountTextFieldFormatter = {
    let maximumIntegerDigits = 9
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = ","
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumFractionDigits = 2
    numberFormatter.roundingMode = .down
    let amountInputFormatController = SendAmountTextFieldFormatter(
      currencyFormatter: numberFormatter,
      maximumIntegerDigits: maximumIntegerDigits
    )
    amountInputFormatController.shouldUpdateCursorLocation = false
    return amountInputFormatController
  }()
  
  private func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
}

private extension TransactionViewModelImplementation {
  func createModel() -> TransactionView.Model {
    let imageTask = TKCore.ImageDownloadTask { [weak self, imageLoader] imageView, size, cornerRadius in
      return imageLoader.loadImage(
        url: self?.buySellItem.iconURL,
        imageView: imageView,
        size: size,
        cornerRadius: cornerRadius
      )
    }
    
    let rate = currencyRateFormatter.format(currency: currency, rate: buySellItem.rate)
    
    var payCurrency: String
    var getCurrency: String
    
    switch transactionModel.type {
    case .buy:
      payCurrency = currency.rawValue
      getCurrency = TonInfo.symbol
    case .sell:
      payCurrency = TonInfo.symbol
      getCurrency = currency.rawValue
    }
    
    let payField = TransactionView.Model.InputField(
      placeholder: "You pay",
      currency: payCurrency,
      amount: payAmountInput,
      isValid: isPayAmountValid
    )
    
    let getField = TransactionView.Model.InputField(
      placeholder: "You get",
      currency: getCurrency,
      amount: getAmountInput,
      isValid: isGetAmountValid
    )
    
    return TransactionView.Model(
      image: .asyncImage(imageTask),
      providerName: buySellItem.title,
      providerDescription: buySellItem.description,
      rate: rate,
      payField: payField,
      getField: getField,
      isContinueButtonEnabled: isPayAmountValid && isGetAmountValid,
      isErrorShown: validationErrorMessage != nil,
      errorMessage: validationErrorMessage
    )
  }
}
