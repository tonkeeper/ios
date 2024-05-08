import UIKit
import TKUIKit
import KeeperCore
import TKCore
import BigInt

struct BuySellOperationModel {
  let item: BuySellItem
  let paymentMethodId: String
}

struct BuySellItem {
  enum Operation: Hashable {
    case buy
    case sell
  }
  
  var operation: Operation
  var token: Token
  var amount: BigUInt
}

struct BuySellModel {
  struct Amount {
    struct Token {
      let title: String
    }
    
    let text: String
    let fractionDigits: Int
    let minimum: String
    let token: Token
  }
  
  struct FiatAmount {
    let converted: String
    let currency: Currency
  }

  struct Button {
    let title: String
    let isEnabled: Bool
    let isActivity: Bool
    let action: (() -> Void)
  }
  
  let amount: Amount?
  let fiatAmount: FiatAmount
  let button: Button
}

public struct PaymentMethodItemsModel {
  public let paymentMethodItems: [Item]
  
  public init(paymentMethodItems: [Item]) {
    self.paymentMethodItems = paymentMethodItems
  }
}

public extension PaymentMethodItemsModel {
  struct Item {
    public let identifier: String
    public let title: String
    public let image: UIImage
  }
}

protocol BuySellModuleOutput: AnyObject {
  var didContinueBuySell: ((BuySellOperationModel) -> Void)? { get set }
}

protocol BuySellModuleInput: AnyObject {
  
}

protocol BuySellViewModel: AnyObject {
  var didUpdateModel: ((BuySellModel) -> Void)? { get set }
  var didUpdateCountryCode: ((String) -> Void)? { get set }
  var didUpdatePaymentMethodItems: (([PaymentMethodItemCell.Configuration]) -> Void)? { get set }
  
  var buySellAmountTextFieldFormatter: BuySellAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmount(_ string: String)
  func didSelectPaymentMethodId(_ id: String)
  func didChangeOperation(_ operation: BuySellItem.Operation)
}

final class BuySellViewModelImplementation: BuySellViewModel, BuySellModuleOutput, BuySellModuleInput {
  
  // MARK: - BuySellModelModuleOutput
  
  var didContinueBuySell: ((BuySellOperationModel) -> Void)?
  
  // MARK: - BuySellModelModuleInput
  
  
  // MARK: - BuySellModelViewModel
  
  var didUpdateModel: ((BuySellModel) -> Void)?
  var didUpdateCountryCode: ((String) -> Void)?
  var didUpdatePaymentMethodItems: (([PaymentMethodItemCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    updateMinimumAmountInput()
    updateCountryCode()
    update()
    
    // TODO: Add BuySellController didChangeRegion
    
    let testItemsModel = PaymentMethodItemsModel(paymentMethodItems: [
      PaymentMethodItemsModel.Item(identifier: "0", title: "Credit Card", image: .TKUIKit.Images.mastercardVisaCardsLogo),
      PaymentMethodItemsModel.Item(identifier: "1", title: "Credit Card  ·  RUB", image: .TKUIKit.Images.mirCardLogo),
      PaymentMethodItemsModel.Item(identifier: "2", title: "Cryptocurrency", image: .TKUIKit.Images.cryptocyrrencyLogo),
      PaymentMethodItemsModel.Item(identifier: "3", title: "Apple Pay", image: .TKUIKit.Images.applePayCardLogo),
    ])
    
    didUpdatePaymentMethodModel(testItemsModel)
  }
  
  func didInputAmount(_ string: String) {
    Task {
      guard string != amountInput else { return }
      
      let unformatted = buySellAmountTextFieldFormatter.unformatString(string) ?? ""
      let amount = buySellController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: tokenFractionalDigits(token: buySellItem.token))
      let isAmountValid = minimumValidAmount <= amount.value
      
      await MainActor.run {
        self.amountInput = unformatted
        self.buySellItem.amount = amount.value
        self.isAmountValid = isAmountValid
        updateConverted()
        update()
      }
    }
  }
  
  func didSelectPaymentMethodId(_ id: String) {
    selectedPaymentMethodId = id
  }
  
  func didUpdatePaymentMethodModel(_ model: PaymentMethodItemsModel) {
    let paymentMethodItems = model.paymentMethodItems.map {
      listItemMapper.mapPaymentMethodItem($0)
    }
    
    Task { @MainActor in
      didUpdatePaymentMethodItems?(paymentMethodItems)
    }
  }
  
  func didChangeOperation(_ operation: BuySellItem.Operation) {
    buySellItem.operation = operation
    updatePaymentMethodList()
  }
  
  // MARK: - State
  
  private var countryCode = "🌍"
  private var amountInput = "0"
  private var minimumAmountInput = "0" {
    didSet {
      guard minimumAmountInput != oldValue else { return }
      updateMinimumValidAmount()
    }
  }
  private var minimumValidAmount = BigUInt()
  private var convertedValue = "0"
  private var currency = Currency.USD
  private var selectedPaymentMethodId = ""
  
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
  
  private var isContinueEnable: Bool {
    isAmountValid
  }
  
  // MARK: - Formatter
  
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
  
  // MARK: - Mapper
  
  private let listItemMapper = BuySellListItemMapper()
  
  // MARK: - Dependencies
  
  private let buySellController: BuySellController
  private var buySellItem: BuySellItem
  
  // MARK: - Init
  
  init(buySellController: BuySellController, appSettings: AppSettings, buySellItem: BuySellItem) {
    self.buySellController = buySellController
    self.buySellItem = buySellItem
    self.buySellAmountTextFieldFormatter.maximumFractionDigits = tokenFractionalDigits(token: buySellItem.token)
  }
}

// MARK: - Private

private extension BuySellViewModelImplementation {
  func createModel() -> BuySellModel {
    return BuySellModel(
      amount: createAmountModel(token: buySellItem.token),
      fiatAmount: BuySellModel.FiatAmount(converted: "\(convertedValue)", currency: currency),
      button: BuySellModel.Button(
          title: "Continue",
          isEnabled: !isResolving && isContinueEnable,
          isActivity: isResolving,
          action: { [weak self] in
            guard let self else { return }
            let operationModel = BuySellOperationModel(
              item: buySellItem,
              paymentMethodId: selectedPaymentMethodId
            )
            didContinueBuySell?(operationModel)
          }
        )
      )
  }
    
  func createAmountModel(token: Token) -> BuySellModel.Amount {
    return BuySellModel.Amount(
      text: buySellAmountTextFieldFormatter.formatString(amountInput) ?? "",
      fractionDigits: tokenFractionalDigits(token: token),
      minimum: minimumAmountInput,
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
  
  func updateMinimumAmountInput() {
    // TODO: minimum amount
    minimumAmountInput = "50"
    didInputAmount(minimumAmountInput)
  }
  
  func updateMinimumValidAmount() {
    let unformatted = buySellAmountTextFieldFormatter.unformatString(minimumAmountInput) ?? ""
    let amount = buySellController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: tokenFractionalDigits(token: buySellItem.token))
    minimumValidAmount = amount.value
  }
  
  func updateCountryCode() {
    Task {
      guard let countryCode = await buySellController.getCountryCode() else { return }
      
      await MainActor.run {
        self.countryCode = countryCode
        didUpdateCountryCode?(countryCode)
      }
    }
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
  
  func updatePaymentMethodList() {
    // TODO: Fetch data
    
    var items = [
      PaymentMethodItemsModel.Item(identifier: "0", title: "Credit Card", image: .TKUIKit.Images.mastercardVisaCardsLogo),
      PaymentMethodItemsModel.Item(identifier: "1", title: "Credit Card  ·  RUB", image: .TKUIKit.Images.mirCardLogo),
      PaymentMethodItemsModel.Item(identifier: "2", title: "Cryptocurrency", image: .TKUIKit.Images.cryptocyrrencyLogo),
    ]
    
    if buySellItem.operation == .buy {
      items.append(PaymentMethodItemsModel.Item(identifier: "3", title: "Apple Pay", image: .TKUIKit.Images.applePayCardLogo))
    }
    
    didUpdatePaymentMethodModel(PaymentMethodItemsModel(paymentMethodItems: items))
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
