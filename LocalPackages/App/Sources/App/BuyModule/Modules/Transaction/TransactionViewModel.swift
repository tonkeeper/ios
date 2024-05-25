import UIKit
import KeeperCore
import TKCore
import TKUIKit
import TKLocalize
import BigInt

protocol TransactionViewModelOutput: AnyObject {
  var didContinue: ((TransactionAmountModel) -> Void)? { get set }
}

protocol TransactionViewModel: AnyObject {
  var didUpdateModel: ((TransactionView.Model) -> Void)? { get set }
  
  var sendAmountTextFieldFormatter: SendAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmount(_ string: String)
  func didInputPayAmount(_ string: String)
  func didInputGetAmount(_ string: String)
  func didTapContinueButton()
}

final class TransactionViewModelImplementation: TransactionViewModel, TransactionViewModelOutput {
  
  // MARK: - TransactionViewModelOutput
  
  var didContinue: ((TransactionAmountModel) -> Void)?
  
  // MARK: - TransactionViewModel
  
  var didUpdateModel: ((TransactionView.Model) -> Void)?
  
  // MARK: - State
  
  private let buySellItem: BuySellItemModel
  private let transactionModel: TransactionAmountModel
  
  private var payAmountInput = ""
  private var getAmountInput = ""
  
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
  
  private let buyListController: BuyListController
  private let exchangeConverter: ExchangeConfirmationConverter
  private let currencyRateFormatter: CurrencyToTONFormatter
  private let currency: Currency
  
  init(
    buySellItem: BuySellItemModel,
    transactionModel: TransactionAmountModel,
    currency: Currency,
    buyListController: BuyListController,
    exchangeConverter: ExchangeConfirmationConverter,
    currencyRateFormatter: CurrencyToTONFormatter
  ) {
    self.buySellItem = buySellItem
    self.transactionModel = transactionModel
    self.currency = currency
    self.buyListController = buyListController
    self.exchangeConverter = exchangeConverter
    self.currencyRateFormatter = currencyRateFormatter
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
    update()
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
    update()
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
    update()
  }
  
  func didInputAmount(_ string: String) {
//    testCalculator(string)
//    
//    
//    
//    let amount = buyListController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: TonInfo.fractionDigits)
//    let convertedAmount = convertAmount(amount.amount)
//    
//    
//    switch transactionModel.mode {
//    case .buy:
//      let isAmountValid = !amount.amount.isZero
//      self.payAmountInput = unformatted
//      self.payAmount = amount.amount
//      self.getAmountInput = sendAmountTextFieldFormatter.formatString(convertedAmount.description.string) ?? ""
//      self.convertedAmount = convertedAmount
//      self.isAmountValid = isAmountValid
//      update()
//    case .sell:
//      Task {
//        let isAmountValid = await buyListController.isAmountAvailableToSend(amount: amount.amount, token: .ton) && !amount.amount.isZero
//        await MainActor.run {
//          self.amountInput = unformatted
//          self.amount = amount.amount
//          self.isAmountValid = isAmountValid
//          updateConverted()
//          update()
//        }
//      }
//    }
  }
  
  func didTapContinueButton() {
    didContinue?(transactionModel)
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
    
    return TransactionView.Model(
      image: .asyncImage(imageTask),
      providerName: buySellItem.title,
      providerDescription: buySellItem.description,
      rate: rate,
      toPlaceholder: "You get",
      fromPlaceholder: "You pay",
      fromCurrency: payCurrency,
      toCurrency: getCurrency,
      toAmountString: getAmountInput,
      fromAmountString: payAmountInput,
      isContinueButtonEnabled: isContinueEnabled,
      isMinAmountShown: false,
      minAmountDisclaimer: "WAT"
    )
  }
}
