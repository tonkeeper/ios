import UIKit
import TKUIKit
import KeeperCore
import TKCore
import BigInt
import TKLocalize

protocol StakeModulOutput: AnyObject {
  var didContinueStake: (() -> Void)? { get set }
  var showOptions: (() -> Void)? { get set }
}

protocol StakeModulInput: AnyObject {
  
}

protocol StakeViewModel: AnyObject {
  
  var didUpdateModel: ((StakeView.Model) -> Void)? { get set }
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func didInputAmount(_ string: String)
  func didTapToOptions()
  
}

final class StakeViewModelImplementation: StakeViewModel, StakeModulOutput, StakeModulInput {
  
  // MARK: - State
  private var recipient: Recipient?
  private var sendItem: SendItem
  private var amountInput = ""
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  private var convertedValue = ""
  private var remaining: SendV3Controller.Remaining = .remaining("")
  
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
  
  let sendAmountTextFieldFormatter: SendAmountTextFieldFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = " "
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    let amountInputFormatController = SendAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
    return amountInputFormatController
  }()
  
  // MARK: - CustomizeWalletViewModel
  
  var didUpdateModel: ((StakeView.Model) -> Void)?
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)?
  var didTapMax: ((String) -> Void)?
  var didContinueStake: (() -> Void)?
  var showOptions: (() -> Void)?
  
  // MARK: - Dependencies
  private let imageLoader = ImageLoader()
  
  private let sendController: SendV3Controller
  private let walletsStore: WalletsStore
  private let currencyStore: CurrencyStore
  private let amountFormatter: AmountFormatter
  
  // MARK: - Init
  
  init(
    sendController: SendV3Controller,
    walletsStore: WalletsStore,
    currencyStore: CurrencyStore,
    amountFormatter: AmountFormatter
  ) {
    self.sendController = sendController
    self.walletsStore = walletsStore
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
    
    self.sendItem = SendItem.token(.ton, amount: 0)
    
    switch sendItem {
    case .token(let token, _):
      sendAmountTextFieldFormatter.maximumFractionDigits = tokenFractionalDigits(token: token)
    case .nft:
      break
    }
  }
  
  func viewDidLoad() {
    updateRemaining()
    update()
  }
  
  func didInputAmount(_ string: String) {
    
    Task {
      guard string != amountInput else { return }
      let token: Token = .ton
      
      let unformatted = self.sendAmountTextFieldFormatter.unformatString(string) ?? ""
      let amount = sendController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: tokenFractionalDigits(token: token))
      let isAmountValid = await sendController.isAmountAvailableToSend(amount: amount.amount, token: token) && !amount.amount.isZero
      // let amount = await sendController.getMaximumAmount(token: token) тотал баланс
      
      await MainActor.run {
        self.remaining = remaining
        self.amountInput = unformatted
        self.sendItem = .token(token, amount: amount.amount)
        self.isAmountValid = isAmountValid
        updateConverted()
        updateRemaining()
        update()
      }
    }
  }
  
  func didTapToOptions() {
    showOptions?()
  }
  
}

private extension StakeViewModelImplementation {
  
  func createModel() -> StakeView.Model {
    
    let amountModel: StakeView.Model.Amount?
    switch sendItem {
    case .nft:
      amountModel = nil
    case .token(let token, _):
      amountModel = createAmountModel(token: token)
    }
    
    let remaining: StakeView.Model.Balance.Remaining
    switch self.remaining {
    case .insufficient:
      remaining = .insufficient
    case .remaining(let string):
      remaining = .remaining(string)
    }
    
    let button = StakeView.Model.Button(
      title: TKLocales.Actions.continue_action,
      isEnabled: isContinueEnable,
      isActivity: true,
      action: { [weak self] in
        guard let self else { return }
        self.didContinueStake?()
      }
    )
    
    let balance = StakeView.Model.Balance(
      converted: "\(convertedValue)",
      remaining: remaining
    )
    
    return StakeView.Model(
      balance: balance,
      button: button,
      amount: amountModel
    )
  }
  
  func createAmountModel(token: Token) -> StakeView.Model.Amount {
    return StakeView.Model.Amount(
      placeholder: TKLocales.Send.Amount.placeholder,
      text: sendAmountTextFieldFormatter.formatString(amountInput) ?? "",
      fractionDigits: tokenFractionalDigits(token: token),
      token: createTokenModel(token: token)
    )
  }
  
  func createTokenModel(token: Token) -> StakeView.Model.Amount.Token {
    let title: String
    let image: StakeView.Model.Amount.Token.Image
    switch token {
    case .ton:
      title = "TON"
      image = .image(.TKCore.Icons.Size44.tonLogo)
    case .jetton(let item):
      title = item.jettonInfo.symbol ?? ""
      image = .asyncImage(ImageDownloadTask(closure: { [weak self] imageView, size, cornerRadius in
        self?.imageLoader.loadImage(url: item.jettonInfo.imageURL, imageView: imageView, size: size, cornerRadius: cornerRadius)
      }))
    }
    
    return StakeView.Model.Amount.Token(
      image: image,
      title: title
    )
  }
  
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func updateRemaining() {
    Task {
      switch sendItem {
      case .nft: break
      case .token(let token, let amount):
        let remaining = await sendController.calculateRemaining(token: token, tokenAmount: amount)
        await MainActor.run {
          self.remaining = remaining
          update()
        }
      }
    }
  }
  
  func updateConverted() {
    Task {
      switch sendItem {
      case .nft: break
      case .token(let token, let amount):
        let converted = await sendController.convertTokenAmountToCurrency(token: token, amount)
        await MainActor.run {
          self.convertedValue = converted
          update()
        }
      }
    }
  }
  
  var isContinueEnable: Bool {
    let isItemValid: Bool
    switch sendItem {
    case .nft:
      isItemValid = true
    case .token:
      isItemValid = isAmountValid
    }
    
    return isItemValid
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
