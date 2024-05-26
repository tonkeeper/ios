import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

public struct PaymentMethodItemsModel {
  public struct Item {
    public let id: String
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
  var didUpdateModel: ((BuySellView.Model) -> Void)? { get set }
  var didUpdateInputAmountText: ((String) -> Void)? { get set }
  var didUpdateCountryCode: ((String?) -> Void)? { get set }
  var didUpdateTabButtonsModel: ((TabButtonsContainerView.Model) -> Void)? { get set }
  var didUpdatePaymentMethodItems: (([SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  
  var textFieldFormatter: InputAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmount(_ string: String)
  func didSelectPaymentMethod(_ paymentMethod: PaymentMethodItemsModel.Item)
  func didChangeOperation(_ operation: BuySellModel.Operation)
}

final class BuySellViewModelImplementation: BuySellViewModel, BuySellModuleOutput {
  
  // MARK: - BuySellModelModuleOutput
  
  var didContinueBuySell: ((BuySellOperatorItem) -> Void)?
  
  // MARK: - BuySellModelViewModel
  
  var didUpdateModel: ((BuySellView.Model) -> Void)?
  var didUpdateInputAmountText: ((String) -> Void)?
  var didUpdateCountryCode: ((String?) -> Void)?
  var didUpdateTabButtonsModel: ((TabButtonsContainerView.Model) -> Void)?
  var didUpdatePaymentMethodItems: (([SelectionCollectionViewCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    updateWithInitalData()
    updateCountryCode()
    updateTabButtonsContainer()
    updatePaymentMethodList()
  }
  
  func didInputAmount(_ string: String) {
    guard string != amountInput else { return }
    amountInput = string
    
    let convertedAmount = convertStringToAmount(string)
    buySellModel.inputAmount = convertedAmount
    amountInputValue = convertedAmount
    isAmountValid = minimumValidAmount <= convertedAmount
    
    updateConverted()
    update()
  }
  
  func didSelectPaymentMethod(_ paymentMethod: PaymentMethodItemsModel.Item) {
    selectedPaymentMethod = paymentMethod
  }
  
  func didChangeOperation(_ operation: BuySellModel.Operation) {
    buySellModel.operation = operation
    updatePaymentMethodList()
  }
  
  // MARK: - State
  
  private var countryCode: String?
  private var amountInput = "0"
  private var amountInputMinimum = "0"
  private var amountInputValue = BigUInt(0)
  private var minimumValidAmount = BigUInt(0)
  private var convertedValue = "0"
  private var currency = Currency.USD
  private var selectedPaymentMethod = PaymentMethodItemsModel.Item.creditCard
  
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
  
  let textFieldFormatter = InputAmountTextFieldFormatter()
  
  // MARK: - Mapper
  
  private let listItemMapper = BuySellListItemMapper()
  
  // MARK: - Dependencies
  
  private let buySellController: BuySellController
  private var buySellModel: BuySellModel
  
  // MARK: - Init
  
  init(buySellController: BuySellController, appSettings: AppSettings, buySellModel: BuySellModel) {
    self.buySellController = buySellController
    self.buySellModel = buySellModel
    self.textFieldFormatter.maximumFractionDigits = buySellModel.token.fractionDigits
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension BuySellViewModelImplementation {
  func updateWithInitalData() {
    let minimumInputAmount = buySellController.convertAmountToString(
      amount: buySellModel.minimumInputAmount,
      fractionDigits: buySellModel.token.fractionDigits
    )
    let inputAmount = buySellController.convertAmountToString(
      amount: buySellModel.inputAmount,
      fractionDigits: buySellModel.token.fractionDigits
    )
    minimumValidAmount = buySellModel.minimumInputAmount
    amountInputValue = buySellModel.inputAmount
    updateAmountInputMinimum(minimumInputAmount)
    didUpdateInputAmountText?(inputAmount)
    didInputAmount(inputAmount)
  }
  
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> BuySellView.Model {
    BuySellView.Model(
      input: BuySellAmountInputView.Model(
        inputCurrency: TonInfo.symbol,
        convertedAmount: BuySellAmountInputView.Model.Amount(
          value: convertedValue,
          currency: currency.code
        ),
        minimum: BuySellAmountInputView.Model.Minimum(
          title: "Min. amount",
          amount: BuySellAmountInputView.Model.Amount(
            value: amountInputMinimum,
            currency: TonInfo.symbol
          )
        )
      ),
      button: BuySellView.Model.Button(
        title: TKLocales.Actions.continue_action,
        isEnabled: !isResolving && isContinueEnable,
        isActivity: isResolving,
        action: { [weak self] in
          guard let self else { return }
          didContinueBuySell?(createBuySellOperatorItem())
        }
      )
    )
  }
  
  func createBuySellOperatorItem() -> BuySellOperatorItem {
    BuySellOperatorItem(
      buySellModel: buySellModel,
      paymentMethod: .init(
        id: selectedPaymentMethod.id,
        title: selectedPaymentMethod.title
      ),
      countryCode: countryCode
    )
  }
  
  func updateAmountInputMinimum(_ string: String) {
    amountInputMinimum = string
    minimumValidAmount = convertStringToAmount(string)
  }
  
  func convertStringToAmount(_ string: String) -> BigUInt {
    let unformatted = textFieldFormatter.unformatString(string) ?? "0"
    let converted = buySellController.convertStringToAmount(
      string: unformatted,
      targetFractionalDigits: buySellModel.token.fractionDigits
    )
    return converted.amount
  }
  
  func updateAmountInput(with inputAmount: String) {
    didInputAmount(inputAmount)
  }
  
  func updateCountryCode() {
    Task {
      let countryCode = await buySellController.getCountryCode()
      await MainActor.run {
        self.countryCode = countryCode
        didUpdateCountryCode?(countryCode)
      }
    }
  }
  
  func updateConverted() {
    let amountValue = amountInputValue
    Task {
      let currency = await buySellController.getActiveCurrency()
      let convertedValue = await buySellController.convertTokenAmountToCurrency(
        token: buySellModel.token,
        amount: amountValue,
        currency: currency
      )
      await MainActor.run {
        self.convertedValue = convertedValue
        self.currency = currency
        update()
      }
    }
  }
  
  func updateTabButtonsContainer() {
    let model = createTabButtonsContainerModel()
    didUpdateTabButtonsModel?(model)
  }
  
  func createTabButtonsContainerModel() -> TabButtonsContainerView.Model {
    TabButtonsContainerView.Model(tabButtons: [
      TabButtonItem.Model(title: "Buy") { [weak self] in self?.didChangeOperation(.buy) },
      TabButtonItem.Model(title: "Sell") { [weak self] in self?.didChangeOperation(.sell) },
    ])
  }
  
  func updatePaymentMethodList() {
    var items: [PaymentMethodItemsModel.Item] = [
      .creditCard,
      .creditCardRUB,
      .cryptocurrency
    ]
    
    if buySellModel.operation == .buy {
      items.append(.applePay)
    }
    
    didUpdatePaymentMethodModel(PaymentMethodItemsModel(items: items))
  }
  
  func didUpdatePaymentMethodModel(_ model: PaymentMethodItemsModel) {
    let paymentMethodItems = model.items.map { item in
      listItemMapper.mapPaymentMethodItem(item) { [weak self] in
        self?.didSelectPaymentMethod(item)
      }
    }
    
    Task { @MainActor in
      didUpdatePaymentMethodItems?(paymentMethodItems)
    }
  }
}

private extension PaymentMethodItemsModel.Item {
  static let creditCard = PaymentMethodItemsModel.Item(
    id: "creditCard",
    title: "Credit Card",
    image: .TKUIKit.Images.mastercardVisaCardsLogo
  )
  static let creditCardRUB = PaymentMethodItemsModel.Item(
    id: "creditCardRub",
    title: "Credit Card  ·  RUB",
    image: .TKUIKit.Images.mirCardLogo
  )
  static let cryptocurrency = PaymentMethodItemsModel.Item(
    id: "cryptocurrency",
    title: "Cryptocurrency",
    image: .TKUIKit.Images.cryptocyrrencyLogo
  )
  static let applePay = PaymentMethodItemsModel.Item(
    id: "creditCardRub",
    title: "Apple Pay",
    image: .TKUIKit.Images.applePayCardLogo
  )
}
