import UIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

struct SwapItem {
  // TODO: Add jetton
  struct Token {
    enum Icon {
      case image(UIImage)
      case asyncImage(ImageDownloadTask)
    }
    
    struct Balance {
      var amount: BigUInt
    }
    
    var icon: Icon
    var title: String
    var inputAmount: String
    var balance: Balance
  }
  
  var sendToken: Token?
  var recieveToken: Token?
}

private extension SwapItem.Token.Icon {
  var tokenButtonIcon: SwapAmountInputView.Model.Icon {
    switch self {
    case .image(let image):
      return .image(image)
    case .asyncImage(let imageDownloadTask):
      return .asyncImage(imageDownloadTask)
    }
  }
}

extension SwapItem.Token {
  static let ton = SwapItem.Token(
    icon: .image(.TKCore.Icons.Size44.tonLogo),
    title: "TON",
    inputAmount: "0",
    balance: SwapItem.Token.Balance(
      amount: BigUInt(stringLiteral: "0")
    )
  )
  
  static let usdt = SwapItem.Token(
    icon: .image(.TKCore.Icons.Size44.tonLogo),
    title: "USDT",
    inputAmount: "0",
    balance: SwapItem.Token.Balance(
      amount: BigUInt(stringLiteral: "35359000000")
    )
  )
}

private extension BigUInt {
  static let testBalanceAmount = BigUInt(stringLiteral: "100000010000000")
}



//struct SwapRate {
//  var rate: String
//}

//struct SwapDetails {
//  var priceImpact: String
//  var minimumRecieved: String
//  var liquidityProviderFee: String
//  var blockchainFee: String
//  var route: String
//  var provider: String
//}

struct SwapModel {
  struct SwapButton {
    let action: (() -> Void)?
  }
  
  let title: String
  let swapButton: SwapButton
}

enum SwapActionButtonState {
  case enterAmount
  case chooseToken
  case insufficientBalanceTon
  case insufficientBalance
  case continueSwap
}

struct SwapActionButtonModel {
  let title: String
  let backgroundColor: UIColor
  let backgroundColorHighlighted: UIColor
  let isEnabled: Bool
  let isActivity: Bool
  let action: (() -> Void)?
}

enum SwapInput {
  case send
  case recieve
}

protocol SwapModuleOutput: AnyObject {
  var didTapSwapSettings: (() -> Void)? { get set }
  var didTapTokenButton: ((SwapItem.Token?, SwapInput) -> Void)? { get set }
  var didTapBuyTon: (() -> Void)? { get set }
  var didTapContinue: (() -> Void)? { get set }
}

protocol SwapModuleInput: AnyObject {
  func didChooseToken(_ token: SwapItem.Token, forInput input: SwapInput)
}

protocol SwapViewModel: AnyObject {
  var didUpdateModel: ((SwapModel) -> Void)? { get set }
  var didUpdateActionButtonModel: ((SwapActionButtonModel) -> Void)? { get set }
  var didUpdateAmountSend: ((String) -> Void)? { get set }
  var didUpdateAmountRecieve: ((String) -> Void)? { get set }
  var didUpdateSendTokenBalance: ((String) -> Void)? { get set }
  var didUpdateRecieveTokenBalance: ((String) -> Void)? { get set }
  var didUpdateSwapSendContainer: ((SwapSendContainerView.Model) -> Void)? { get set }
  var didUpdateSwapRecieveContainer: ((SwapRecieveContainerView.Model) -> Void)? { get set }
  var amountInpuTextFieldFormatter: BuySellAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmountSend(_ string: String)
  func didInputAmountRecieve(_ string: String)
  func didTapMaxButton()
  func didTapSwapButton()
}

final class SwapViewModelImplementation: SwapViewModel, SwapModuleOutput, SwapModuleInput {
  
  enum Remaining: Equatable {
    case remaining(String)
    case insufficient
    
    var value: String {
      switch self {
      case .remaining(let value):
        return value
      case .insufficient:
        return "0"
      }
    }
  }
  
  // MARK: - SwapModuleOutput
  
  var didTapSwapSettings: (() -> Void)?
  var didTapTokenButton: ((SwapItem.Token?, SwapInput) -> Void)?
  var didTapBuyTon: (() -> Void)?
  var didTapContinue: (() -> Void)?
  
  // MARK: - SwapModuleInput
  
  func didChooseToken(_ token: SwapItem.Token, forInput input: SwapInput) {
    switch input {
    case .send:
      swapItem.sendToken = token
      amountSend = "0"
      didUpdateAmountSend?(amountSend)
    case .recieve:
      swapItem.recieveToken = token
      amountRecieve = "0"
      didUpdateAmountRecieve?(amountRecieve)
    }
    
    update()
    updateSendBalance()
    updateRecieveBalance()
    updateActionButton()
  }
  
  // MARK: - SwapViewModel
  
  var didUpdateModel: ((SwapModel) -> Void)?
  var didUpdateActionButtonModel: ((SwapActionButtonModel) -> Void)?
  var didUpdateAmountSend: ((String) -> Void)?
  var didUpdateAmountRecieve: ((String) -> Void)?
  var didUpdateSendTokenBalance: ((String) -> Void)?
  var didUpdateRecieveTokenBalance: ((String) -> Void)?
  var didUpdateSwapSendContainer: ((SwapSendContainerView.Model) -> Void)?
  var didUpdateSwapRecieveContainer: ((SwapRecieveContainerView.Model) -> Void)?
  
  func viewDidLoad() {
    update()
    updateActionButton()
    
//    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//      self.swapItem.sendToken?.balance.amount = .testBalanceAmount
//      self.updateSendBalance()
//    }
//    
//    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//      self.swapItem.recieveToken = .usdt
//      self.updateRecieveBalance()
//      self.update()
//    }
//    
//    didTapTokenButton = { [self] token, input in
//      // TODO: Fetch token data
//      var newToken: SwapItem.Token
//      switch input {
//      case .send:
//        newToken = .ton
//      case .recieve:
//        newToken = .usdt
//      }
//      
//      didChooseToken(newToken, forInput: input)
//    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.didTapTokenButton?(self.swapItem.sendToken, .send)
    }
    
    Task {
      await swapController.start()
    }
  }
  
  func didInputAmountSend(_ string: String) {
    amountSend = string
    lastInput = .send
    
//    let unformatted = amountInpuTextFieldFormatter.unformatString(string) ?? ""
//    let inputAmount = swapController.convertStringToAmount(string: string, targetFractionalDigits: TonInfo.fractionDigits)
    
    updateSendBalance()
    updateActionButton()
  }
  
  func didInputAmountRecieve(_ string: String) {
    amountRecieve = string
    lastInput = .recieve
    
    updateActionButton()
  }
  
  func didTapMaxButton() {
    guard let sendToken = swapItem.sendToken else { return }
    
    lastInput = .send
    
    let balanceAmountSend = swapController.convertAmountToString(amount: sendToken.balance.amount, fractionDigits: TonInfo.fractionDigits)
    
    let unformattedAmountSend = amountInpuTextFieldFormatter.unformatString(balanceAmountSend) ?? "0"
    let formattedAmountSend = amountInpuTextFieldFormatter.formatString(unformattedAmountSend) ?? "0"
    
    didInputAmountSend(formattedAmountSend)
    didUpdateAmountSend?(formattedAmountSend)
  }
  
  func didTapSwapButton() {
    let sendToken = swapItem.sendToken
    swapItem.sendToken = swapItem.recieveToken
    swapItem.recieveToken = sendToken
    
    swap(&amountSend, &amountRecieve)
    
    didUpdateAmountRecieve?(amountRecieve)
    didUpdateAmountSend?(amountSend)
    
    switch lastInput {
    case .send:
      lastInput = .recieve
      didInputAmountRecieve(amountRecieve)
    case .recieve:
      lastInput = .send
      didInputAmountSend(amountSend)
    }
    
    update()
    updateSendBalance()
    updateRecieveBalance()
  }
  
  // MARK: - State
  
  private var amountSend = "0"
  private var amountRecieve = "0"
  private var tokenSendBalanceRemaining = Remaining.remaining("0")
  private var tokenRecieveBalance = "0"
  private var lastInput = SwapInput.send
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  private var isContinueEnable: Bool {
    true
  }
  
  // MARK: - Formatter
  
  let amountInpuTextFieldFormatter: BuySellAmountTextFieldFormatter = .makeAmountFormatter()
  
  // MARK: - Dependencies
  
  private let swapController: SwapController
  private var swapItem: SwapItem
  
  // MARK: - Init
  
  init(swapController: SwapController, swapItem: SwapItem) {
    self.swapController = swapController
    self.swapItem = swapItem
    self.amountInpuTextFieldFormatter.maximumFractionDigits = TonInfo.fractionDigits
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension SwapViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
    
    let swapSendContainerModel = createSwapSendContainerModel()
    let swapRecieveContainerModel = createSwapRecieveContainerModel()
    
    didUpdateSwapSendContainer?(swapSendContainerModel)
    didUpdateSwapRecieveContainer?(swapRecieveContainerModel)
  }
  
  func createModel() -> SwapModel {
    SwapModel(
      title: "Swap",
      swapButton: SwapModel.SwapButton(
        action: { [weak self] in
          self?.didTapSwapButton()
        }
      )
    )
  }
  
  func createSwapSendContainerModel() -> SwapSendContainerView.Model {
    var isInputEnabled = false
    var balanceTitle: String?
    var maxButton: SwapInputContainerView.Model.HeaderButton?
    
    if swapItem.sendToken != nil {
      isInputEnabled = true
      balanceTitle = createBalanceTitle(balance: tokenSendBalanceRemaining.value)
      maxButton = SwapInputContainerView.Model.HeaderButton(
        title: "MAX",
        action: { [weak self] in
          self?.didTapMaxButton()
        }
      )
    }
    
    return SwapSendContainerView.Model(
      inputContainerModel: SwapInputContainerView.Model(
        headerTitle: "Send",
        balanceTitle: balanceTitle,
        maxButton: maxButton,
        tokenButton: mapTokenButton(token: swapItem.sendToken, forInput: .send),
        isInputEnabled: isInputEnabled
      )
    )
  }
  
  func createSwapRecieveContainerModel() -> SwapRecieveContainerView.Model {
    var isInputEnabled = false
    var balanceTitle: String?
    
    if swapItem.recieveToken != nil {
      isInputEnabled = true
      balanceTitle = createBalanceTitle(balance: tokenRecieveBalance)
    }
    
    return SwapRecieveContainerView.Model(
      inputContainerModel: SwapInputContainerView.Model(
        headerTitle: "Recieve",
        balanceTitle: balanceTitle,
        maxButton: nil,
        tokenButton: mapTokenButton(token: swapItem.recieveToken, forInput: .recieve),
        isInputEnabled: isInputEnabled
      )
    )
  }
  
  func mapTokenButton(token: SwapItem.Token?, forInput input: SwapInput) -> SwapInputContainerView.Model.TokenButton {
    if let token {
      return SwapInputContainerView.Model.TokenButton(
        title: token.title,
        icon: token.icon.tokenButtonIcon,
        action: { [weak self] in
          self?.didTapTokenButton?(token, input)
        }
      )
    } else {
      return SwapInputContainerView.Model.TokenButton(
        title: "CHOOSE",
        icon: .image(nil),
        action: { [weak self] in
          self?.didTapTokenButton?(token, input)
        }
      )
    }
  }
  
  func updateSendBalance() {
    guard let sendToken = swapItem.sendToken else {
      tokenSendBalanceRemaining = .insufficient
      return
    }
    
    let unformatted = amountInpuTextFieldFormatter.unformatString(amountSend) ?? ""
    let inputAmount = swapController.convertStringToAmount(string: unformatted, targetFractionalDigits: TonInfo.fractionDigits)
    
    if inputAmount.value <= sendToken.balance.amount {
      let remainingBalanceAmount = sendToken.balance.amount - inputAmount.value
      let remainingBalanceString = swapController.convertAmountToString(amount: remainingBalanceAmount, fractionDigits: TonInfo.fractionDigits)
      tokenSendBalanceRemaining = .remaining(remainingBalanceString)
    } else {
      tokenSendBalanceRemaining = .insufficient
    }
    
    let balanceTitle = createBalanceTitle(balance: tokenSendBalanceRemaining.value)
    didUpdateSendTokenBalance?(balanceTitle)
  }
  
  func updateRecieveBalance() {
    guard let recieveToken = swapItem.recieveToken else {
      tokenRecieveBalance = "0"
      return
    }
    
    let balanceString = swapController.convertAmountToString(amount: recieveToken.balance.amount, fractionDigits: TonInfo.fractionDigits)
    let balanceTitle = createBalanceTitle(balance: balanceString)
    tokenRecieveBalance = balanceString
    didUpdateRecieveTokenBalance?(balanceTitle)
  }
  
  func createBalanceTitle(balance: String) -> String {
    "Balance: \(balance)"
  }
  
  func updateActionButton() {
    let hasSendToken = swapItem.sendToken != nil
    let hasRecieveToken = swapItem.recieveToken != nil
    
    let actionButtonState: SwapActionButtonState

    switch (amountSend, amountRecieve, hasSendToken, hasRecieveToken) {
    case ("0", "0", true, true), ("0", _, true, false):
      actionButtonState = .enterAmount
    case (_, "0", false, true):
      actionButtonState = .chooseToken
    case (_, _, true, _) where tokenSendBalanceRemaining == .insufficient:
      actionButtonState = actionButtonStateForInsufficient(sendTokenTitle: swapItem.sendToken?.title)
    case (_, _, true, false), (_, _, false, true):
      actionButtonState = .chooseToken
    case (_, _, true, true) where amountSend != "0" && amountRecieve != "0":
      actionButtonState = .continueSwap
    default:
      actionButtonState = .enterAmount
    }
    
    print(actionButtonState)
    
    let actionButtonModel = createActionButton(forState: actionButtonState)
    didUpdateActionButtonModel?(actionButtonModel)
  }
  
  func actionButtonStateForInsufficient(sendTokenTitle: String?) -> SwapActionButtonState {
    if sendTokenTitle == "TON" {
      return .insufficientBalanceTon
    } else {
      return .insufficientBalance
    }
  }
  
  func createActionButton(forState actionButtonState: SwapActionButtonState) -> SwapActionButtonModel {
    switch actionButtonState {
    case .enterAmount:
      return createEnterAmountButton()
    case .chooseToken:
      return createChoseTokenButton()
    case .insufficientBalanceTon:
      return createInsufficientBalanceTonButton()
    case .insufficientBalance:
      return createInsufficientBalanceButton()
    case .continueSwap:
      return createContinueButton()
    }
  }
  
  func createEnterAmountButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Enter Amount",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: !isResolving,
      isActivity: isResolving,
      action: nil
    )
  }
  
  func createChoseTokenButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Choose Token",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: !isResolving,
      isActivity: isResolving,
      action: nil
    )
  }
  
  func createInsufficientBalanceTonButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Insufficient Balance. Buy TON",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: !isResolving,
      isActivity: isResolving,
      action: { [weak self] in
        self?.didTapBuyTon?()
      }
    )
  }
  
  func createInsufficientBalanceButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Insufficient \(swapItem.sendToken?.title ?? "") balance",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: !isResolving,
      isActivity: isResolving,
      action: nil
    )
  }
  
  func createContinueButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Continue",
      backgroundColor: .Button.primaryBackground,
      backgroundColorHighlighted: .Button.primaryBackgroundHighlighted,
      isEnabled: !isResolving && isContinueEnable,
      isActivity: isResolving,
      action: { [weak self] in
        self?.didTapContinue?()
      }
    )
  }
}

private extension BuySellAmountTextFieldFormatter {
  static func makeAmountFormatter() -> BuySellAmountTextFieldFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.groupingSeparator = " "
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    return BuySellAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
  }
}
