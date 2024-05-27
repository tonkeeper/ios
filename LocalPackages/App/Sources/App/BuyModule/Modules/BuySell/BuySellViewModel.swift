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
  func didTapConvertedButton()
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
    guard string != inputItem.amountString else { return }
    updateBuySellItems(withInput: string)
  }
  
  func didTapConvertedButton() {
    buySellItem.input = buySellItem.input.opposite
    textFieldFormatter.maximumFractionDigits = inputItem.fractionDigits
    didUpdateInputAmountText?(inputItem.amountString)
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
  
  private var buySellItem = BuySellItem(input: .token, tokenItem: .ton, fiatItem: .usd)
  
  private var inputItem: BuySellItem.Item {
    buySellItem.getItem(forInput: buySellItem.input)
  }
  private var outputItem: BuySellItem.Item {
    buySellItem.getItem(forInput: buySellItem.output)
  }
  
  private var countryCode: String?
  private var minimumValidTokenAmountString = "0"
  private var minimumValidTokenAmount = BigUInt(0)
  private var selectedPaymentMethod = PaymentMethodItemsModel.Item.creditCard
  
  private var isAmountValid: Bool = false {
    didSet {
      guard isAmountValid != oldValue else { return }
      update()
    }
  }
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
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
  
  init(buySellController: BuySellController, buySellModel: BuySellModel) {
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
    let minimumTokenAmountString = buySellController.convertAmountToString(
      amount: buySellModel.minimumTokenAmount,
      fractionDigits: buySellModel.token.fractionDigits
    )
    let tokenAmountString = buySellController.convertAmountToString(
      amount: buySellModel.tokenAmount,
      fractionDigits: buySellModel.token.fractionDigits
    )
    
    buySellItem = BuySellItem(
      input: .token,
      tokenItem: BuySellItem.Token(
        amount: buySellModel.tokenAmount,
        amountString: tokenAmountString,
        token: buySellModel.token
      ),
      fiatItem: BuySellItem.Fiat(
        amount: 0,
        amountString: "0",
        currency: .USD
      )
    )
    
    minimumValidTokenAmount = buySellModel.minimumTokenAmount
    updateMinimumValidAmount(minimumTokenAmountString)
    
    update()
    updateFiatCurrency()
    reloadBuySellItems()
    didUpdateInputAmountText?(tokenAmountString)
  }
  
  func updateBuySellItems(withInput string: String) {
    let input = buySellItem.input
    let inputAmount = convertStringToAmount(string, targetFractionDigits: inputItem.fractionDigits)
    
    let tokenItem = buySellItem.tokenItem
    let fiatItem = buySellItem.fiatItem
    
    Task {
      let updatedToken: BuySellItem.Token
      let updatedFiat: BuySellItem.Fiat
      
      switch input {
      case .token:
        updatedToken = tokenItem.updated(amount: inputAmount, amountString: string)
        updatedFiat = await buySellController.convertTokenToFiat(updatedToken, currency: fiatItem.currency)
      case .fiat:
        updatedFiat = fiatItem.updated(amount: inputAmount, amountString: string)
        updatedToken = await buySellController.convertFiatToToken(updatedFiat, token: tokenItem.token)
      }
      
      await MainActor.run {
        buySellItem.tokenItem = updatedToken
        buySellItem.fiatItem = updatedFiat
        
        buySellModel.tokenAmount = updatedToken.amount
        isAmountValid = minimumValidTokenAmount <= updatedToken.amount
        
        update()
      }
    }
  }
  
  func reloadBuySellItems() {
    updateBuySellItems(withInput: inputItem.amountString)
  }
  
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> BuySellView.Model {
    BuySellView.Model(
      input: BuySellAmountInputView.Model(
        inputCurrency: inputItem.currencyCode,
        convertedAmount: BuySellAmountInputView.Model.Amount(
          value: outputItem.amountString,
          currency: outputItem.currencyCode
        ),
        minimum: BuySellAmountInputView.Model.Minimum(
          title: "Min. amount",
          amount: BuySellAmountInputView.Model.Amount(
            value: minimumValidTokenAmountString,
            currency: buySellItem.tokenItem.currencyCode
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
      buySellItem: buySellItem,
      paymentMethod: .init(
        id: selectedPaymentMethod.id,
        title: selectedPaymentMethod.title
      ),
      countryCode: countryCode
    )
  }
  
  func updateFiatCurrency() {
    Task {
      let activeCurrency = await buySellController.getActiveCurrency()
      await MainActor.run {
        guard buySellItem.fiatItem.currency != activeCurrency else { return }
        buySellItem.fiatItem.currency = activeCurrency
        reloadBuySellItems()
      }
    }
  }
  
  func updateMinimumValidAmount(_ string: String) {
    minimumValidTokenAmountString = string
    minimumValidTokenAmount = convertStringToAmount(string, targetFractionDigits: buySellItem.tokenItem.fractionDigits)
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
  
  func convertStringToAmount(_ string: String, targetFractionDigits: Int) -> BigUInt {
    let unformatted = textFieldFormatter.unformatString(string) ?? "0"
    let converted = buySellController.convertStringToAmount(
      string: unformatted,
      targetFractionalDigits: targetFractionDigits
    )
    return converted.amount
  }
}

private extension PaymentMethodItemsModel.Item {
  static let creditCard = PaymentMethodItemsModel.Item(
    id: "creditCard",
    title: "Credit Card",
    image: .TKUIKit.Images.PaymentMethods.mastercardVisaCardsLogo
  )
  static let creditCardRUB = PaymentMethodItemsModel.Item(
    id: "creditCardRub",
    title: "Credit Card  ·  RUB",
    image: .TKUIKit.Images.PaymentMethods.mirCardLogo
  )
  static let cryptocurrency = PaymentMethodItemsModel.Item(
    id: "cryptocurrency",
    title: "Cryptocurrency",
    image: .TKUIKit.Images.PaymentMethods.cryptocyrrencyLogo
  )
  static let applePay = PaymentMethodItemsModel.Item(
    id: "creditCardRub",
    title: "Apple Pay",
    image: .TKUIKit.Images.PaymentMethods.applePayCardLogo
  )
}
