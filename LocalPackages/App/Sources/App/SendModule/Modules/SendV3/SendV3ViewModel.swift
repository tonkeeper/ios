import UIKit
import KeeperCore
import TKCore
import BigInt
import TKLocalize

protocol SendV3ModuleOutput: AnyObject {
  var didContinueSend: ((SendModel) -> Void)? { get set }
  var didTapPicker: ((Wallet, Token) -> Void)? { get set }
  var didTapScan: (() -> Void)? { get set }
}

protocol SendV3ModuleInput: AnyObject {
  func updateWithToken(_ token: Token)
  func setRecipient(string: String)
}

protocol SendV3ViewModel: AnyObject {
  var didUpdateModel: ((SendV3View.Model) -> Void)? { get set }
  
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
}

final class SendV3ViewModelImplementation: SendV3ViewModel, SendV3ModuleOutput, SendV3ModuleInput {
  
  // MARK: - SendV3ModuleOutput
  
  var didContinueSend: ((SendModel) -> Void)?
  var didTapPicker: ((Wallet, Token) -> Void)?
  var didTapScan: (() -> Void)?
  
  // MARK: - SendV3ModuleInput
  
  var didUpdateModel: ((SendV3View.Model) -> Void)?
  
  func updateWithToken(_ token: Token) {
    sendAmountTextFieldFormatter.maximumFractionDigits = token.tokenFractionalDigits
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
  
  // MARK: - SendV3ViewModel
  
  func viewDidLoad() {
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
      guard !Task.isCancelled else { return }
      guard let recipient = await sendController.resolveRecipient(input: string) else {
        await MainActor.run {
          self.recipient = nil
          self.isRecipientValid = false
          self.isResolving = false
          self.isCommentRequired = false
        }
        return
      }
      
      await MainActor.run {
        self.recipient = recipient
        self.isRecipientValid = true
        self.isResolving = false
        self.isCommentRequired = recipient.isMemoRequired
      }
    }
  }
  
  func didInputAmount(_ string: String) {
    switch sendItem {
    case .token(let token, _):
      Task {
        guard string != amountInput else { return }
        let unformatted = self.sendAmountTextFieldFormatter.unformatString(string) ?? ""
        let amount = sendController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: token.tokenFractionalDigits)
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
    update()
  }
  
  func didTapWalletTokenPicker() {
    switch sendItem {
    case .token(let token, _):
      self.didTapPicker?(walletsStore.activeWallet, token)
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
  
  private let imageLoader = ImageLoader()
  private let sendController: SendV3Controller
  private let walletsStore: WalletsStore
  
  // MARK: - Init
  
  init(sendItem: SendItem,
       recipient: Recipient?,
       sendController: SendV3Controller,
       walletsStore: WalletsStore) {
    self.sendItem = sendItem
    self.recipient = recipient
    self.sendController = sendController
    self.walletsStore = walletsStore
    
    switch sendItem {
    case .token(let token, _):
      sendAmountTextFieldFormatter.maximumFractionDigits = token.tokenFractionalDigits
    case .nft:
      break
    }
  }
}

private extension SendV3ViewModelImplementation {
  func createModel() -> SendV3View.Model {
    
    let commentModel = createCommentModel()
    let amountModel: SendV3View.Model.Amount?
    switch sendItem {
    case .nft:
      amountModel = nil
    case .token(let token, _):
      amountModel = createAmountModel(token: token)
    }
    
    let remaining: SendV3View.Model.Balance.Remaining
    switch self.remaining {
    case .insufficient:
      remaining = .insufficient
    case .remaining(let string):
      remaining = .remaining(string)
    }
    
    return SendV3View.Model(
      recipient: createRecipientModel(),
      amount: amountModel,
      balance: SendV3View.Model.Balance(
        converted: "\(convertedValue)",
        remaining: remaining
      ),
      comment: commentModel,
      button: SendV3View.Model.Button(
        title: TKLocales.Actions.continue_action,
        isEnabled: !isResolving && isContinueEnable,
        isActivity: isResolving,
        action: { [weak self] in
          guard let self else { return }
          let sendModel = SendModel(wallet: walletsStore.activeWallet,
                                    recipient: recipient,
                                    sendItem: sendItem,
                                    comment: commentInput)
          didContinueSend?(sendModel)
        }
      )
    )
  }
  
  func createRecipientModel() -> SendV3View.Model.Recipient {
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
    return SendV3View.Model.Recipient(
      placeholder: TKLocales.Send.Recepient.placeholder,
      text: text,
      isValid: isValid
    )
  }
  
  func createCommentModel() -> SendV3View.Model.Comment {
    let description: NSAttributedString?
    let placeholder: String
    switch (isCommentRequired, commentInput.isEmpty) {
    case (false, true):
      placeholder = TKLocales.Send.Comment.placeholder
      description = nil
    case (false, false):
      placeholder = TKLocales.Send.Comment.placeholder
      description = TKLocales.Send.Comment.description.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
    case (true, _):
      placeholder = TKLocales.Send.RequiredComment.placeholder
      description = TKLocales.Send.RequiredComment.description
        .withTextStyle(
          .body2,
          color: .Accent.orange,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        )
    }
    
    return SendV3View.Model.Comment(
      placeholder: placeholder,
      text: commentInput,
      isValid: true,
      description: description
    )
  }
  
  func createAmountModel(token: Token) -> SendV3View.Model.Amount {
    return SendV3View.Model.Amount(
      placeholder: TKLocales.Send.Amount.placeholder,
      text: sendAmountTextFieldFormatter.formatString(amountInput) ?? "",
      fractionDigits: token.tokenFractionalDigits,
      token: createTokenModel(token: token)
    )
  }
  
  func createTokenModel(token: Token) -> SendV3View.Model.Amount.Token {
    let title: String
    let image: SendV3View.Model.Amount.Token.Image
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
    
    return SendV3View.Model.Amount.Token(
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
    
    return recipient != nil && (isCommentRequired && !commentInput.isEmpty || !isCommentRequired) && isItemValid
  }
}
