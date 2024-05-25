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

struct BuySellDetailsModel {
  enum Icon {
    case image(UIImage?)
    case asyncImage(TKCore.ImageDownloadTask)
  }
  
  struct TextField {
    let placeholder: String
    let currencyCode: String
  }
  
  struct Button {
    let title: String
    let isEnabled: Bool
    let isActivity: Bool
    let action: (() -> Void)
  }
  
  struct InfoContainer {
    struct InfoButton {
      let title: String
      let action: (() -> Void)
    }
    
    let description: String
    let leftButton: InfoButton?
    let rightButton: InfoButton?
  }
  
  let icon: Icon
  let title: String
  let subtitle: String
  let textFieldPay: TextField
  let textFieldGet: TextField
  let convertedRate: String
  let infoContainer: InfoContainer
  let continueButton: Button
}

protocol BuySellDetailsModuleOutput: AnyObject {
  var didTapContinue: ((URL?) -> Void)? { get set }
  var didTapInfoButton: ((URL?) -> Void)? { get set }
}

protocol BuySellDetailsViewModel: AnyObject {
  var didUpdateModel: ((BuySellDetailsModel) -> Void)? { get set }
  var didUpdateAmountPay: ((String) -> Void)? { get set }
  var didUpdateAmountGet: ((String) -> Void)? { get set }
  var didUpdateConvertedRate: ((String) -> Void)? { get set }
  
  var payAmountTextFieldFormatter: InputAmountTextFieldFormatter { get }
  var getAmountTextFieldFormatter: InputAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmountPay(_ string: String)
  func didInputAmountGet(_ string: String)
}

final class BuySellDetailsViewModelImplementation: BuySellDetailsViewModel, BuySellDetailsModuleOutput {
  
  typealias Input = BuySellDetailsController.Input
  
  enum InputCurrencyType {
    case token
    case fiat
  }
  
  enum InputField {
    case pay
    case get
  }
  
  // MARK: - BuySellDetailsModelModuleOutput
  
  var didTapContinue: ((URL?) -> Void)?
  var didTapInfoButton: ((URL?) -> Void)?
  
  // MARK: - BuySellDetailsModelViewModel
  
  var didUpdateModel: ((BuySellDetailsModel) -> Void)?
  var didUpdateAmountPay: ((String) -> Void)?
  var didUpdateAmountGet: ((String) -> Void)?
  var didUpdateConvertedRate: ((String) -> Void)?
  
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
      await buySellDetailsController.loadRate(for: buySellTransactionModel.operation.fiatCurrency)
    }
  }
  
  func didInputAmountPay(_ string: String) {
    guard string != amountPay else { return }
    Task {
      await processInputAmount(
        inputString: string,
        inputField: .pay,
        onConverted: { [weak self] formattedInput, convertedOutput in
          self?.amountPay = formattedInput
          self?.amountGet = convertedOutput
          self?.didUpdateAmountPay?(formattedInput)
          self?.didUpdateAmountGet?(convertedOutput)
        }
      )
    }
  }
  
  func didInputAmountGet(_ string: String) {
    guard string != amountGet else { return }
    Task {
      await processInputAmount(
        inputString: string,
        inputField: .get,
        onConverted: { [weak self] formattedInput, convertedOutput in
          self?.amountGet = formattedInput
          self?.amountPay = convertedOutput
          self?.didUpdateAmountGet?(formattedInput)
          self?.didUpdateAmountPay?(convertedOutput)
        }
      )
    }
  }
  
  // MARK: - State
  
  private var amountPay = ""
  private var amountGet = ""
  private var convertedRate = ""
  private var actionURL: URL?
  
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
    isActionUrlExists
  }
  
  // MARK: - Formatters
  
  let payAmountTextFieldFormatter = InputAmountTextFieldFormatter()
  let getAmountTextFieldFormatter = InputAmountTextFieldFormatter()
  
  // MARK: - Dependencies
  
  private let imageLoader = ImageLoader()
  
  private let buySellDetailsController: BuySellDetailsController
  private var buySellDetailsItem: BuySellDetailsItem
  private var buySellTransactionModel: BuySellTransactionModel
  
  // MARK: - Init
  
  init(buySellDetailsController: BuySellDetailsController, buySellDetailsItem: BuySellDetailsItem, buySellTransactionModel: BuySellTransactionModel) {
    self.buySellDetailsController = buySellDetailsController
    self.buySellDetailsItem = buySellDetailsItem
    self.buySellTransactionModel = buySellTransactionModel
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
  
  func updateAmountTextFields() {
    let inputAmount = buySellDetailsController.convertAmountToString(
      amount: buySellTransactionModel.inputAmount,
      fractionDigits: buySellTransactionModel.token.fractionDigits
    )
    switch buySellTransactionModel.operation {
    case .buyTon:
      didInputAmountGet(inputAmount)
    case .sellTon:
      didInputAmountPay(inputAmount)
    }
  }
  
  func updateConvertedRate() {
    Task {
      let amount = BigUInt(stringLiteral: "1")
      let payAmount = mapInputAmount(amount, from: .get)
      let payInput = Input(amount: payAmount, fractionLength: 0)
      let currency = buySellTransactionModel.operation.fiatCurrency
      let outputFractionLenght = maximumFractionDigits(forInputField: .pay)
      let convertedRate = await buySellDetailsController.convertAmountInput(
        input: payInput,
        providerRate: buySellTransactionModel.providerRate,
        currency: currency,
        outputFractionLenght: outputFractionLenght
      )
      await MainActor.run {
        self.convertedRate = convertedRate
        let convertedRateText = createConvertedRateText()
        didUpdateConvertedRate?(convertedRateText)
      }
    }
  }
  
  func updateActionURL() {
    Task {
      let actionURL = await buySellDetailsController.createActionUrl(
        actionTemplateURL: buySellDetailsItem.actionTemplateURL,
        operatorId: buySellDetailsItem.serviceInfo.id,
        currencyFrom: buySellTransactionModel.currencyPay,
        currencyTo: buySellTransactionModel.currencyGet
      )
      await MainActor.run {
        if let actionURL {
          self.actionURL = actionURL
          isActionUrlExists = true
        }
      }
    }
  }
  
  func createModel() -> BuySellDetailsModel {
    let iconURL = buySellDetailsItem.iconURL
    let iconImageDownloadTask = TKCore.ImageDownloadTask { [imageLoader] imageView, size, cornerRadius in
      return imageLoader.loadImage(
        url: iconURL,
        imageView: imageView,
        size: size,
        cornerRadius: cornerRadius
      )
    }
    
    return BuySellDetailsModel(
      icon: .asyncImage(iconImageDownloadTask),
      title: buySellDetailsItem.serviceTitle,
      subtitle: buySellDetailsItem.serviceSubtitle,
      textFieldPay: BuySellDetailsModel.TextField(
        placeholder: "You Pay",
        currencyCode: buySellTransactionModel.currencyPay.code
      ),
      textFieldGet: BuySellDetailsModel.TextField(
        placeholder: "You Get",
        currencyCode: buySellTransactionModel.currencyGet.code
      ),
      convertedRate: createConvertedRateText(),
      infoContainer: BuySellDetailsModel.InfoContainer(
        description: "Service provided by \(buySellDetailsItem.serviceInfo.provider)",
        leftButton: createInfoButton(buySellDetailsItem.serviceInfo.leftButton),
        rightButton: createInfoButton(buySellDetailsItem.serviceInfo.rightButton)
      ),
      continueButton: BuySellDetailsModel.Button(
        title: TKLocales.Actions.continue_action,
        isEnabled: !isResolving && isContinueEnable,
        isActivity: isResolving,
        action: { [weak self] in
          self?.didTapContinue?(self?.actionURL)
        }
      )
    )
  }
  
  func createConvertedRateText() -> String {
    let currencyPay = buySellTransactionModel.currencyPay
    let currencyGet = buySellTransactionModel.currencyGet
    return "\(convertedRate) \(currencyPay.code) for 1 \(currencyGet.code)"
  }
  
  func createInfoButton(_ button: BuySellDetailsItem.ServiceInfo.InfoButton?) -> BuySellDetailsModel.InfoContainer.InfoButton? {
    guard let button else { return nil }
    return .init(title: button.title) { [weak self] in
      self?.didTapInfoButton?(button.url)
    }
  }
  
  func processInputAmount(inputString string: String,
                          inputField: InputField,
                          onConverted: @escaping (String, String) -> Void) async {
    let formattedInput = formatInputString(string, from: inputField)
    let convertedOutput = await convertInputString(formattedInput: formattedInput, from: inputField)
    await MainActor.run {
      onConverted(formattedInput, convertedOutput)
    }
  }
  
  func formatInputString(_ string: String, from inputField: InputField) -> String {
    let textFormatter = textFormatter(forInputField: inputField)
    let unformatted = textFormatter.unformatString(string) ?? ""
    return textFormatter.formatString(unformatted) ?? ""
  }
  
  func convertInputString(formattedInput: String, from inputField: InputField) async -> String {
    let convertedOutput: String
    if !formattedInput.isEmpty {
      let unformatted = textFormatter(forInputField: inputField).unformatString(formattedInput) ?? ""
      
      let outputField: InputField = inputField == .pay ? .get : .pay
      
      let maximumFractionDigitsInput = maximumFractionDigits(forInputField: inputField)
      let maximumFractionDigitsOuput = maximumFractionDigits(forInputField: outputField)
      
      let convertedInput = buySellDetailsController.convertStringToAmount(
        string: unformatted,
        targetFractionalDigits: maximumFractionDigitsInput
      )
      let input = Input(
        amount: mapInputAmount(convertedInput.amount, from: inputField),
        fractionLength: convertedInput.fractionalDigits
      )
      convertedOutput = await buySellDetailsController.convertAmountInput(
        input: input,
        providerRate: buySellTransactionModel.providerRate,
        currency: buySellTransactionModel.operation.fiatCurrency,
        outputFractionLenght: maximumFractionDigitsOuput
      )
    } else {
      convertedOutput = ""
    }
    
    return convertedOutput
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
    switch inputCurrencyType(forInputField: inputField) {
    case .token:
      return buySellTransactionModel.token.fractionDigits
    case .fiat:
      return 2
    }
  }
  
  func mapInputAmount(_ amount: BigUInt, from inputField: InputField) -> Input.Amount {
    switch inputCurrencyType(forInputField: inputField) {
    case .token:
      return .ton(amount)
    case .fiat:
      return .fiat(amount)
    }
  }
  
  func inputCurrencyType(forInputField inputField: InputField) -> InputCurrencyType {
    switch (buySellTransactionModel.operation, inputField) {
    case (.buyTon, .pay):
      return .fiat
    case (.buyTon, .get):
      return .token
    case (.sellTon, .pay):
      return .token
    case (.sellTon, .get):
      return .fiat
    }
  }
}
