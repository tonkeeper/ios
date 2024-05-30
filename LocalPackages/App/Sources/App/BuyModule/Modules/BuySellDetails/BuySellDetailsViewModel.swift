import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

struct BuySellDetailsItem {
  struct ServiceInfo {
    struct InfoButton {
      var title: String
      var url: URL?
    }
    
    var id: String
    var provider: String
    var leftButton: InfoButton?
    var rightButton: InfoButton?
  }
  
  var iconURL: URL?
  var actionTemplateURL: String?
  var serviceTitle: String
  var serviceSubtitle: String
  var serviceInfo: ServiceInfo
}

extension BuySellDetailsItem.ServiceInfo.InfoButton {
  var titledUrl: TitledURL? {
    TitledURL(title: title, url: url)
  }
}

protocol BuySellDetailsModuleOutput: AnyObject {
  var didTapContinue: ((TitledURL?) -> Void)? { get set }
  var didTapInfoButton: ((TitledURL?) -> Void)? { get set }
}

protocol BuySellDetailsViewModel: AnyObject {
  var didUpdateModel: ((BuySellDetailsView.Model) -> Void)? { get set }
  var didUpdateAmountPay: ((String) -> Void)? { get set }
  var didUpdateAmountGet: ((String) -> Void)? { get set }
  var didUpdateIsTokenAmountValid: ((Bool) -> Void)? { get set }
  var didUpdateRateContainerModel: ((ListDescriptionContainerView.Model) -> Void)? { get set }
  var didUpdateContinueButtonModel: ((BuySellDetailsView.Model.Button) -> Void)? { get set }
  
  var payAmountTextFieldFormatter: InputAmountTextFieldFormatter { get }
  var getAmountTextFieldFormatter: InputAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmountPay(_ string: String)
  func didInputAmountGet(_ string: String)
}

final class BuySellDetailsViewModelImplementation: BuySellDetailsViewModel, BuySellDetailsModuleOutput {
  
  enum InputField {
    case pay
    case get
  }
  
  // MARK: - BuySellDetailsModelModuleOutput
  
  var didTapContinue: ((TitledURL?) -> Void)?
  var didTapInfoButton: ((TitledURL?) -> Void)?
  
  // MARK: - BuySellDetailsModelViewModel
  
  var didUpdateModel: ((BuySellDetailsView.Model) -> Void)?
  var didUpdateAmountPay: ((String) -> Void)?
  var didUpdateAmountGet: ((String) -> Void)?
  var didUpdateIsTokenAmountValid: ((Bool) -> Void)?
  var didUpdateRateContainerModel: ((ListDescriptionContainerView.Model) -> Void)?
  var didUpdateContinueButtonModel: ((BuySellDetailsView.Model.Button) -> Void)?
  
  func viewDidLoad() {
    update()
    updateAmountTextFields()
    updateConvertedRate()
    updateActionURL()
    
    buySellDetailsController.didUpdateRates = { [weak self] in
      self?.updateConvertedRate()
      self?.updateAmountTextFields()
    }
    
    Task {
      await buySellDetailsController.start()
      await buySellDetailsController.loadRate(for: buySellItem.fiatItem.currency)
    }
  }
  
  func didInputAmountPay(_ string: String) {
    guard string != itemPay.amountString else { return }
    updateBuySellItems(withInput: string, at: .pay)
  }
  
  func didInputAmountGet(_ string: String) {
    guard string != itemGet.amountString else { return }
    updateBuySellItems(withInput: string, at: .get)
  }
  
  // MARK: - State
  
  private var buySellItem: BuySellItem {
    get { buySellTransactionModel.buySellItem }
    set { buySellTransactionModel.buySellItem = newValue }
  }
  
  private var itemPay: BuySellItem.Item {
    buySellTransactionModel.itemSell
  }
  private var itemGet: BuySellItem.Item {
    buySellTransactionModel.itemBuy
  }
  
  private var convertedRate = ""
  private var actionURL: URL?
  
  private var isTokenAmountValid: Bool = true {
    didSet {
      didUpdateIsTokenAmountValid?(isTokenAmountValid)
      guard isTokenAmountValid != oldValue else { return }
      updateContinueButton()
    }
  }
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  private var isActionUrlExists: Bool = false {
    didSet {
      guard isActionUrlExists != oldValue else { return }
      update()
    }
  }
  
  private var isContinueEnable: Bool {
    isActionUrlExists && isTokenAmountValid
  }
  
  // MARK: - Formatters
  
  let payAmountTextFieldFormatter = InputAmountTextFieldFormatter()
  let getAmountTextFieldFormatter = InputAmountTextFieldFormatter()
  
  // MARK: - Dependencies
  
  private let imageLoader = ImageLoader()
  
  private let buySellDetailsController: BuySellDetailsController
  private var buySellTransactionModel: BuySellTransactionModel
  private var buySellDetailsItem: BuySellDetailsItem
  
  // MARK: - Init

  init(buySellDetailsController: BuySellDetailsController, buySellTransactionModel: BuySellTransactionModel, buySellDetailsItem: BuySellDetailsItem) {
    self.buySellDetailsController = buySellDetailsController
    self.buySellTransactionModel = buySellTransactionModel
    self.buySellDetailsItem = buySellDetailsItem
    self.payAmountTextFieldFormatter.maximumFractionDigits = maximumFractionDigits(forInputField: .pay)
    self.getAmountTextFieldFormatter.maximumFractionDigits = maximumFractionDigits(forInputField: .get)
    self.payAmountTextFieldFormatter.isAllowedEmptyInput = true
    self.getAmountTextFieldFormatter.isAllowedEmptyInput = true
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension BuySellDetailsViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> BuySellDetailsView.Model {
    let iconURL = buySellDetailsItem.iconURL
    let iconImageDownloadTask = TKCore.ImageDownloadTask { [imageLoader] imageView, size, cornerRadius in
      return imageLoader.loadImage(
        url: iconURL,
        imageView: imageView,
        size: size,
        cornerRadius: cornerRadius
      )
    }
    return BuySellDetailsView.Model(
      serviceInfo: ServiceInfoContainerView.Model(
        image: .asyncImage(iconImageDownloadTask),
        title: buySellDetailsItem.serviceTitle.withTextStyle(.h2, color: .Text.primary),
        subtitle: buySellDetailsItem.serviceSubtitle.withTextStyle(.body1, color: .Text.secondary)
      ),
      textFieldPay: BuySellDetailsView.Model.TextField(
        placeholder: "You Pay",
        currencyCode: itemPay.currencyCode
      ),
      textFieldGet: BuySellDetailsView.Model.TextField(
        placeholder: "You Get",
        currencyCode: itemGet.currencyCode
      ),
      rateContainer: createRateContainerModel(convertedRate: convertedRate),
      serviceProvidedTitle: "Service provided by \(buySellDetailsItem.serviceInfo.provider)".withTextStyle(.body2, color: .Text.tertiary),
      infoButtonsContainer: InfoButtonsContainerView.Model(
        leftButton: createInfoButton(buySellDetailsItem.serviceInfo.leftButton),
        rightButton: createInfoButton(buySellDetailsItem.serviceInfo.rightButton)
      ),
      continueButton: createContinueButtonModel()
    )
  }
  
  func createRateContainerModel(convertedRate: String) -> ListDescriptionContainerView.Model {
    let fiatItemCurrencyCode = buySellItem.fiatItem.currencyCode
    let tokenItemCurrencyCode = buySellItem.tokenItem.currencyCode
    let description = "\(convertedRate) \(fiatItemCurrencyCode) for 1 \(tokenItemCurrencyCode)"
    return ListDescriptionContainerView.Model(
      description: description.withTextStyle(.body2, color: .Text.tertiary)
    )
  }
  
  func createInfoButton(_ infoButton: BuySellDetailsItem.ServiceInfo.InfoButton?) -> InfoButtonsContainerView.Model.Button? {
    guard let infoButton else { return nil }
    return InfoButtonsContainerView.Model.Button(
      title: infoButton.title.withTextStyle(.body2, color: .Text.secondary),
      action: { [weak self] in
        self?.didTapInfoButton?(infoButton.titledUrl)
      }
    )
  }
  
  func updateContinueButton() {
    let model = createContinueButtonModel()
    didUpdateContinueButtonModel?(model)
  }
  
  func createContinueButtonModel() -> BuySellDetailsView.Model.Button {
    return BuySellDetailsView.Model.Button(
      title: TKLocales.Actions.continue_action,
      isEnabled: !isResolving && isContinueEnable,
      isActivity: isResolving,
      action: { [weak self] in
        guard let self else { return }
        let actionUrl = TitledURL(title: self.buySellDetailsItem.serviceTitle, url: self.actionURL)
        self.didTapContinue?(actionUrl)
      }
    )
  }
  
  func updateAmountTextFields() {
    let tokenItem = buySellItem.tokenItem
    let inputAmount = buySellDetailsController.convertAmountToString(
      amount: tokenItem.amount,
      fractionDigits: tokenItem.fractionDigits
    )
    switch buySellTransactionModel.operation {
    case .buy:
      updateBuySellItems(withInput: inputAmount, at: .get)
    case .sell:
      updateBuySellItems(withInput: inputAmount, at: .pay)
    }
  }
  
  func updateBuySellItems(withInput string: String, at inputField: InputField) {
    let input = itemInput(atInputField: inputField)
    let itemFractionDigits = buySellItem.getItem(forInput: input).fractionDigits
    let inputAmount = convertStringToAmount(string, fromInput: inputField, targetFractionDigits: itemFractionDigits)
    
    let tokenItem = buySellItem.tokenItem
    let fiatItem = buySellItem.fiatItem
    let providerRate = buySellTransactionModel.providerRate
    
    Task {
      let updatedToken: BuySellItem.Token
      let updatedFiat: BuySellItem.Fiat
      
      switch input {
      case .token:
        updatedToken = tokenItem.updated(amount: inputAmount, amountString: string)
        updatedFiat = await buySellDetailsController.convertTokenToFiat(updatedToken, currency: fiatItem.currency, providerRate: providerRate)
      case .fiat:
        updatedFiat = fiatItem.updated(amount: inputAmount, amountString: string)
        updatedToken = await buySellDetailsController.convertFiatToToken(updatedFiat, token: tokenItem.token, providerRate: providerRate)
      }
      
      await MainActor.run {
        buySellItem.tokenItem = updatedToken
        buySellItem.fiatItem = updatedFiat
        
        var strings = amountStrings()
        if updatedToken.amountString.isEmpty || updatedFiat.amountString.isEmpty {
          strings = ("", "")
        }
        
        didUpdateAmountGet?(strings.amountGet)
        didUpdateAmountPay?(strings.amoutPay)
        didUpdateTokenAmount(buySellItem.tokenItem.amount)
      }
    }
  }
  
  func convertStringToAmount(_ string: String, fromInput input: InputField, targetFractionDigits: Int) -> BigUInt {
    let unformatted = textFormatter(forInputField: input).unformatString(string) ?? "0"
    let converted = buySellDetailsController.convertStringToAmount(
      string: unformatted,
      targetFractionalDigits: targetFractionDigits
    )
    return converted.amount
  }
  
  func amountStrings() -> (amoutPay: String, amountGet: String) {
    return (itemPay.amountString, itemGet.amountString)
  }
  
  func updateConvertedRate() {
    let tokenItem = buySellItem.tokenItem
    let fiatItem = buySellItem.fiatItem
    Task {
      let oneToken = BuySellItem.Token(
        amount: 1,
        amountString: "1",
        token: BuySellModel.Token(
          symbol: tokenItem.token.symbol,
          title: tokenItem.token.title,
          fractionDigits: 0
        )
      )
      let convertedRate = await buySellDetailsController.getConvertedRate(
        token: oneToken,
        currency: fiatItem.currency,
        providerRate: buySellTransactionModel.providerRate
      )
      await MainActor.run {
        self.convertedRate = convertedRate
        let rateContainerModel = createRateContainerModel(convertedRate: convertedRate)
        didUpdateRateContainerModel?(rateContainerModel)
      }
    }
  }
  
  func updateActionURL() {
    Task {
      let actionURL = await buySellDetailsController.createActionUrl(
        actionTemplateURL: buySellDetailsItem.actionTemplateURL,
        operatorId: buySellDetailsItem.serviceInfo.id,
        currencyFrom: itemPay.currencyCode,
        currencyTo: itemGet.currencyCode
      )
      await MainActor.run {
        if let actionURL {
          self.actionURL = actionURL
          isActionUrlExists = true
        }
      }
    }
  }
  
  func didUpdateTokenAmount(_ tokenAmount: BigUInt) {
    guard case let .amount(minBuyAmount, minSellAmount) = buySellTransactionModel.minimumLimits else { return }
    
    switch buySellTransactionModel.operation {
    case .buy:
      isTokenAmountValid = tokenAmount >= minBuyAmount
    case .sell:
      isTokenAmountValid = tokenAmount >= minSellAmount
    }
  }
  
  func textFormatter(forInputField inputField: InputField) -> InputAmountTextFieldFormatter {
    switch inputField {
    case .pay:
      return payAmountTextFieldFormatter
    case .get:
      return getAmountTextFieldFormatter
    }
  }
  
  func maximumFractionDigits(forInputField inputField: InputField) -> Int {
    switch itemInput(atInputField: inputField) {
    case .token:
      return buySellTransactionModel.buySellItem.tokenItem.fractionDigits
    case .fiat:
      return buySellTransactionModel.buySellItem.fiatItem.fractionDigits
    }
  }
  
  func itemInput(atInputField inputField: InputField) -> BuySellItem.Input {
    switch (buySellTransactionModel.operation, inputField) {
    case (.buy, .pay):
      return .fiat
    case (.buy, .get):
      return .token
    case (.sell, .pay):
      return .token
    case (.sell, .get):
      return .fiat
    }
  }
}
