import UIKit
import TKUIKit
import KeeperCore
import TKCore
import BigInt

struct BuySellItem {
  enum Operation: Hashable {
    case buy
    case sell
  }
  
  var operation: Operation
  var token: Token
  var inputAmount: String
  var minimumInputAmount: String
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
  public struct Item {
    public let identifier: String
    public let title: String
    public let image: UIImage
  }
  
  public let items: [Item]
  
  public init(items: [Item]) {
    self.items = items
  }
}

protocol BuySellModuleOutput: AnyObject {
  var didContinueBuySell: ((BuySellOperatorItem) -> Void)? { get set }
}

protocol BuySellViewModel: AnyObject {
  var didUpdateModel: ((BuySellModel) -> Void)? { get set }
  var didUpdateCountryCode: ((String) -> Void)? { get set }
  var didUpdatePaymentMethodItems: (([SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  
  var buySellAmountTextFieldFormatter: BuySellAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmount(_ string: String)
  func didSelectPaymentMethodId(_ id: String)
  func didChangeOperation(_ operation: BuySellItem.Operation)
}

final class BuySellViewModelImplementation: BuySellViewModel, BuySellModuleOutput {
  
  // MARK: - BuySellModelModuleOutput
  
  var didContinueBuySell: ((BuySellOperatorItem) -> Void)?
  
  // MARK: - BuySellModelViewModel
  
  var didUpdateModel: ((BuySellModel) -> Void)?
  var didUpdateCountryCode: ((String) -> Void)?
  var didUpdatePaymentMethodItems: (([SelectionCollectionViewCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    updateAmountInputMinimum(with: buySellItem.minimumInputAmount)
    updateAmountInput(with: buySellItem.inputAmount)
    updateCountryCode()
    update()
    
    // TODO: Add BuySellController didChangeRegion
    
    let testItemsModel = PaymentMethodItemsModel(items: [
      .init(identifier: "0", title: "Credit Card", image: .TKUIKit.Images.mastercardVisaCardsLogo),
      .init(identifier: "1", title: "Credit Card  ·  RUB", image: .TKUIKit.Images.mirCardLogo),
      .init(identifier: "2", title: "Cryptocurrency", image: .TKUIKit.Images.cryptocyrrencyLogo),
      .init(identifier: "3", title: "Apple Pay", image: .TKUIKit.Images.applePayCardLogo),
    ])
    
    didUpdatePaymentMethodModel(testItemsModel)
    
    let buySellOperatorItem = createBuySellOperatorItem()
    didContinueBuySell?(buySellOperatorItem)
  }
  
  func didInputAmount(_ string: String) {
    guard string != amountInput else { return }
    amountInput = string
    
    Task {
      let unformatted = buySellAmountTextFieldFormatter.unformatString(string) ?? ""
      let inputAmount = buySellController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: tokenFractionalDigits(token: buySellItem.token))
      let isAmountValid = minimumValidAmount <= inputAmount.value
      
      await MainActor.run {
        self.amountInput = unformatted
        self.buySellItem.inputAmount = unformatted
        self.amountInputValue = inputAmount.value
        self.isAmountValid = isAmountValid
        updateConverted()
        update()
      }
    }
  }
  
  func didSelectPaymentMethodId(_ id: String) {
    selectedPaymentMethodId = id
  }
  
  func didChangeOperation(_ operation: BuySellItem.Operation) {
    buySellItem.operation = operation
    updatePaymentMethodList()
  }
  
  // MARK: - State
  
  private var countryCode = "🌍"
  private var amountInput = "0"
  private var amountInputMinimum = "0"
  private var amountInputValue = BigUInt()
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
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension BuySellViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> BuySellModel {
    BuySellModel(
      amount: createAmountModel(amountInput: amountInput, token: buySellItem.token),
      fiatAmount: BuySellModel.FiatAmount(converted: "\(convertedValue)", currency: currency),
      button: BuySellModel.Button(
          title: "Continue",
          isEnabled: !isResolving && isContinueEnable,
          isActivity: isResolving,
          action: { [weak self] in
            guard let self else { return }
            let buySellOperatorItem = createBuySellOperatorItem()
            didContinueBuySell?(buySellOperatorItem)
          }
        )
      )
  }
    
  func createAmountModel(amountInput: String, token: Token) -> BuySellModel.Amount {
    BuySellModel.Amount(
      text: buySellAmountTextFieldFormatter.formatString(amountInput) ?? "",
      fractionDigits: tokenFractionalDigits(token: token),
      minimum: amountInputMinimum,
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
  
  func createBuySellOperatorItem() -> BuySellOperatorItem {
    let amount = buySellAmountTextFieldFormatter.formatString(amountInput) ?? ""
    let buySellOperation: BuySellOperatorItem.Operation = switch buySellItem.operation {
    case .buy:
        .buy(amount: amount)
    case .sell:
        .sell(amount: amount)
    }
    
    return BuySellOperatorItem(
      operation: buySellOperation,
      paymentMethodId: selectedPaymentMethodId
    )
  }
  
  func updateAmountInputMinimum(with amount: String) {
    amountInputMinimum = amount
    updateMinimumValidAmount(with: amount)
  }

  func updateMinimumValidAmount(with amount: String) {
    let unformatted = buySellAmountTextFieldFormatter.unformatString(amount) ?? ""
    let amount = buySellController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: tokenFractionalDigits(token: buySellItem.token))
    minimumValidAmount = amount.value
  }
  
  func updateAmountInput(with inputAmount: String) {
    didInputAmount(inputAmount)
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
      let amountValue = amountInputValue
      let currency = await buySellController.getActiveCurrency()
      let convertedValue = await buySellController.convertTokenAmountToCurrency(token: token, amountValue, currency: currency)
      
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
    
    didUpdatePaymentMethodModel(PaymentMethodItemsModel(items: items))
  }
  
  func didUpdatePaymentMethodModel(_ model: PaymentMethodItemsModel) {
    let paymentMethodItems = model.items.map {
      listItemMapper.mapPaymentMethodItem($0)
    }
    
    Task { @MainActor in
      didUpdatePaymentMethodItems?(paymentMethodItems)
    }
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
