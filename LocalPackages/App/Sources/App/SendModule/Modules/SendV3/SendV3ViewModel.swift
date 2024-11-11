import UIKit
import TKUIKit
import KeeperCore
import TKCore
import BigInt
import TKLocalize

protocol SendV3ModuleOutput: AnyObject {
  var didContinueSend: ((SendModel) -> Void)? { get set }
  var didTapPicker: ((Wallet, Token) -> Void)? { get set }
  var didTapScan: (() -> Void)? { get set }
  var didTapClose: (() -> Void)? { get set }
}

protocol SendV3ModuleInput: AnyObject {
  func updateWithToken(_ token: Token)
  func setRecipient(string: String)
  func setAmount(amount: BigUInt?)
  func setComment(comment: String?)
}

protocol SendV3ViewModel: AnyObject {
  var didUpdateModel: ((Model) -> Void)? { get set }
  
  var sendAmountTextFieldFormatter: SendAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputRecipient(_ string: String)
  func didInputComment(_ string: String)
  func didInputAmount(_ string: String)
  func didTapWalletTokenPicker()
  func didTapMax()
  func didTapRecipientPasteButton()
  func didTapCommentPasteButton()
  func didTapRecipientScanButton()
  func didTapCloseButton()
}

struct Model {
  struct Recipient {
    let placeholder: String
    let text: String
    let isValid: Bool
  }
  
  struct Amount {
    let placeholder: String
    let text: String
    let fractionDigits: Int
    let token: TokenPickerButton.Configuration
  }
  
  struct Comment {
    let placeholder: String
    let text: String
    let isValid: Bool
    let description: NSAttributedString?
  }
  
  struct Button {
    let title: String
    let isEnabled: Bool
    let isActivity: Bool
    let action: (() -> Void)
  }
  
  struct Balance {
    enum Remaining {
      case insufficient
      case remaining(String)
    }
    let converted: String
    let remaining: Remaining
  }
  
  let recipient: Recipient
  let amount: Amount?
  let balance: Balance
  let comment: Comment
  let button: Button
}

final class SendV3ViewModelImplementation: SendV3ViewModel, SendV3ModuleOutput, SendV3ModuleInput {
  
  // MARK: - SendV3ModuleOutput
  
  var didContinueSend: ((SendModel) -> Void)?
  var didTapPicker: ((Wallet, Token) -> Void)?
  var didTapScan: (() -> Void)?
  var didTapClose: (() -> Void)?
  
  // MARK: - SendV3ModuleInput
  
  var didUpdateModel: ((Model) -> Void)?
  
  func updateWithToken(_ token: Token) {
    sendAmountTextFieldFormatter.maximumFractionDigits = tokenFractionalDigits(token: token)
    sendItem = .token(token, amount: 0)
    amountInput = ""
    isAmountValid = false
    updateConverted()
    updateRemaining()
    update()
  }
  
  func setRecipient(string: String) {
    didInputRecipient(string)
  }
  
  func setAmount(amount: BigUInt?) {
    guard let amount else { return }
    didInputAmount(amount.description)
  }
  
  func setComment(comment: String?) {
    guard let comment else {
      return
    }
    didInputComment(comment)
  }
  
  // MARK: - SendV3ViewModel
  
  func viewDidLoad() {
    balanceStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateConvertedBalance(let wallet):
        guard observer.wallet == wallet else { return }
        DispatchQueue.main.async {
          observer.updateRemaining()
          observer.update()
        }
      }
    }
    switch sendItem {
    case .token(let token, let amount):
      didInputAmount(sendController.convertAmountToInputString(amount: amount, token: token))
      
    case .nft:
      break
    }
    updateRemaining()
    update()
  }
  
  func didInputRecipient(_ string: String) {
    guard string != recipientInput else { return }
    recipientInput = string
    recipient = nil
    isCommentRequired = false
    isRecipientValid = true
    
    recipientResolveTask?.cancel()
    
    guard !string.isEmpty else {
      self.isResolving = false
      return
    }
    
    isResolving = true
    recipientResolveTask = Task {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      do {
        try Task.checkCancellation()
        let recipient = try await sendController.resolveRecipient(input: string)
        try Task.checkCancellation()
        await MainActor.run {
          self.recipient = recipient
          self.isRecipientValid = true
          self.isResolving = false
          self.isCommentRequired = recipient.isMemoRequired
        }
      } catch {
        guard !error.isCancelledError else { return }
        await MainActor.run {
          self.recipient = recipient
          self.isRecipientValid = true
          self.isResolving = false
          self.isCommentRequired = false
        }
      }
    }
  }
  
  func didInputAmount(_ string: String) {
    switch sendItem {
    case .token(let token, _):
      Task {
        guard string != amountInput else { return }
        let unformatted = self.sendAmountTextFieldFormatter.unformatString(string) ?? ""
        let amount = sendController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: tokenFractionalDigits(token: token))
        let isAmountValid = await sendController.isAmountAvailableToSend(amount: amount.amount, token: token) && !amount.amount.isZero
        
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
    case .nft:
      return
    }
  }
  
  func didInputComment(_ string: String) {
    guard string != commentInput else { return }
    commentInput = string
    commentState = sendController.validateComment(comment: string)
    update()
  }
  
  func didTapWalletTokenPicker() {
    switch sendItem {
    case .token(let token, _):
      self.didTapPicker?(wallet, token)
    case .nft:
      break
    }
  }
  
  func didTapMax() {
    Task {
      switch sendItem {
      case .token(let token, _):
        let amount = await sendController.getMaximumAmount(token: token)
        let formatted = sendController.convertAmountToInputString(amount: amount, token: token)
        await MainActor.run {
          self.amountInput = sendAmountTextFieldFormatter.unformatString(formatted) ?? ""
          self.sendItem = .token(token, amount: amount)
          self.isAmountValid = !amount.isZero
          updateRemaining()
          updateConverted()
          update()
        }
      case .nft:
        break
      }
    }
  }
  
  func didTapRecipientPasteButton() {
    guard let pasteboardString = UIPasteboard.general.string else { return }
    didInputRecipient(pasteboardString)
  }
  
  func didTapCommentPasteButton() {
    guard let pasteboardString = UIPasteboard.general.string else { return }
    didInputComment(pasteboardString)
  }
  
  func didTapRecipientScanButton() {
    didTapScan?()
  }
  
  func didTapCloseButton() {
    didTapClose?()
  }
  
  // MARK: - State
  
  private var recipientInput = ""
  private var commentInput = ""
  private var amountInput = ""
  private var sendItem: SendItem
  private var recipient: Recipient?
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  private var convertedValue = ""
  private var remaining: SendV3Controller.Remaining = .remaining("")
  
  private var recipientResolveTask: Task<Void, Never>?
  
  private var isRecipientValid: Bool = true {
    didSet {
      guard isRecipientValid != oldValue else { return }
      update()
    }
  }
  
  private var isAmountValid: Bool = false {
    didSet {
      guard isAmountValid != oldValue else { return }
      update()
    }
  }
  
  
  private var commentState: SendV3Controller.CommentState = .ok {
    didSet {
      guard commentState != oldValue else { return }
      update()
    }
  }
  private var isCommentRequired: Bool = false {
    didSet {
      guard isCommentRequired != oldValue else { return }
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
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let sendController: SendV3Controller
  private let balanceStore: ConvertedBalanceStore
  private let appSettingsStore: AppSettingsStore
  
  // MARK: - Init
  
  init(wallet: Wallet,
       sendItem: SendItem,
       recipient: Recipient?,
       comment: String?,
       sendController: SendV3Controller,
       balanceStore: ConvertedBalanceStore,
       appSettingsStore: AppSettingsStore) {
    self.wallet = wallet
    self.sendItem = sendItem
    self.recipient = recipient
    self.commentInput = comment ?? ""
    self.sendController = sendController
    self.balanceStore = balanceStore
    self.appSettingsStore = appSettingsStore
    
    switch sendItem {
    case .token(let token, _):
      sendAmountTextFieldFormatter.maximumFractionDigits = tokenFractionalDigits(token: token)
    case .nft:
      break
    }
  }
}

private extension SendV3ViewModelImplementation {
  func createModel() -> Model {
    
    let commentModel = createCommentModel()
    let amountModel: Model.Amount?
    switch sendItem {
    case .nft:
      amountModel = nil
    case .token(let token, _):
      amountModel = createAmountModel(token: token)
    }
    
    let remaining: Model.Balance.Remaining
    switch self.remaining {
    case .insufficient:
      remaining = .insufficient
    case .remaining(let string):
      remaining = .remaining(string)
    }
    
    return Model(
      recipient: createRecipientModel(),
      amount: amountModel,
      balance: Model.Balance(
        converted: "\(convertedValue)",
        remaining: remaining
      ),
      comment: commentModel,
      button: Model.Button(
        title: TKLocales.Actions.continueAction,
        isEnabled: !isResolving && isContinueEnable,
        isActivity: isResolving,
        action: { [weak self] in
          guard let self else { return }
          let sendModel = SendModel(wallet: wallet,
                                    recipient: recipient,
                                    sendItem: sendItem,
                                    comment: commentInput)
          didContinueSend?(sendModel)
        }
      )
    )
  }
  
  func createRecipientModel() -> Model.Recipient {
    let text: String
    let isValid: Bool
    switch recipient {
    case .none:
      text = recipientInput
      isValid = isRecipientValid
    case .some(let recipient):
      isValid = isRecipientValid
      switch recipient.recipientAddress {
      case .raw(let address):
        text = address.toRaw()
      case .friendly(let address):
        text = address.toString()
      case .domain(let domain):
        text = domain.domain
      }
    }
    return Model.Recipient(
      placeholder: TKLocales.Send.Recepient.placeholder,
      text: text,
      isValid: isValid
    )
  }
  
  func createCommentModel() -> Model.Comment {
    let description: NSAttributedString?
    let placeholder: String
    switch (isCommentRequired, commentInput.isEmpty, commentState) {
    case (_, false, .ledgerNonAsciiError):
      placeholder = TKLocales.Send.Comment.placeholder
      description = TKLocales.Send.Comment.asciiError.withTextStyle(
        .body2,
        color: .Accent.red,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
    case (false, true, _):
      placeholder = TKLocales.Send.Comment.placeholder
      description = nil
    case (false, false, _):
      placeholder = TKLocales.Send.Comment.placeholder
      description = TKLocales.Send.Comment.description.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
    case (true, _, _):
      placeholder = TKLocales.Send.RequiredComment.placeholder
      description = TKLocales.Send.RequiredComment.description
        .withTextStyle(
          .body2,
          color: .Accent.orange,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        )
    }
    
    return Model.Comment(
      placeholder: placeholder,
      text: commentInput,
      isValid: commentState == .ok,
      description: description
    )
  }
  
  func createAmountModel(token: Token) -> Model.Amount {
    return Model.Amount(
      placeholder: TKLocales.Send.Amount.placeholder,
      text: sendAmountTextFieldFormatter.formatString(amountInput) ?? "",
      fractionDigits: tokenFractionalDigits(token: token),
      token: TokenPickerButton.Configuration.createConfiguration(token: token)
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
        let remaining = await sendController.calculateRemaining(token: token, tokenAmount: amount, isSecure: appSettingsStore.getState().isSecureMode)
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
    
    return recipient != nil && (isCommentRequired && !commentInput.isEmpty || !isCommentRequired) && isItemValid
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
