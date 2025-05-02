import UIKit
import TKUIKit
import KeeperCore
import TKCore
import BigInt
import TKLocalize
import TronSwift

protocol SendV3ModuleOutput: AnyObject {
  var didContinueSend: ((SendData) -> Void)? { get set }
  var didTapPicker: ((Wallet, SendV3Item) -> Void)? { get set }
  var didTapScan: (() -> Void)? { get set }
  var didTapClose: (() -> Void)? { get set }
  var didOpenURL: ((URL) -> Void)? { get set }
}

protocol SendV3ModuleInput: AnyObject {
  func updateWithToken(_ token: SendV3Item)
  func setRecipient(string: String)
  func setAmount(amount: BigUInt?)
  func setComment(comment: String?)
}

protocol SendV3ViewModel: AnyObject {
  var didUpdateViewState: ((SendV3ViewModelViewState) -> Void)? { get set }
  var didUpdateRecipientPlaceholder: ((String) -> Void)? { get set }
  var didUpdateRecipient: ((String) -> Void)? { get set }
  var didUpdateAmountPlaceholder: ((String) -> Void)? { get set }
  var didUpdateAmount: ((String) -> Void)? { get set }
  var didUpdateAmountIsHidden: ((Bool) -> Void)? { get set }
  var didUpdateToken: ((TokenPickerButton.Configuration) -> Void)? { get set }
  var didUpdateComment: ((String) -> Void)? { get set }
  
  var sendAmountTextFieldFormatter: SendAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputRecipient(_ string: String)
  func didInputAmount(_ string: String)
  func didInputComment(_ string: String)
  func didTapWalletTokenPicker()
  func didTapRecipientPasteButton()
  func didTapCommentPasteButton()
  func didTapRecipientScanButton()
  func didTapCloseButton()
  func didTapMax()
}

struct SendV3ViewModelViewState {
  struct BalanceState {
    enum Remaining {
      case insufficient
      case remaining(String)
    }
    let converted: String
    let remaining: Remaining
  }
  struct CommentState {
    let isValid: Bool
    let placeholder: String
    let description: NSAttributedString?
  }
  struct RecipientDescription {
    let description: NSAttributedString
    let actionItems: [TKActionLabel.ActionItem]
  }

  let isRecipientValid: Bool
  let recipientDescription: RecipientDescription?
  let balanceState: BalanceState
  let continueButtonConfiguration: TKButton.Configuration
  let commentState: CommentState
}


final class SendV3ViewModelImplementation: SendV3ViewModel, SendV3ModuleOutput, SendV3ModuleInput {
  
  // MARK: - SendV3ModuleOutput
  
  var didContinueSend: ((SendData) -> Void)?
  var didTapPicker: ((Wallet, SendV3Item) -> Void)?
  var didTapScan: (() -> Void)?
  var didTapClose: (() -> Void)?
  var didOpenURL: ((URL) -> Void)?
  
  // MARK: - SendV3ModuleInput
  
  var didUpdateViewState: ((SendV3ViewModelViewState) -> Void)?
  var didUpdateRecipientPlaceholder: ((String) -> Void)?
  var didUpdateRecipient: ((String) -> Void)?
  var didUpdateAmountPlaceholder: ((String) -> Void)?
  var didUpdateAmount: ((String) -> Void)?
  var didUpdateAmountIsHidden: ((Bool) -> Void)?
  var didUpdateToken: ((TokenPickerButton.Configuration) -> Void)?
  var didUpdateComment: ((String) -> Void)?
  
  func updateWithToken(_ token: SendV3Item) {
    self.item = token
    didUpdateAmount?("0")
    didUpdateItem()
    updateViewState()
  }
  
  func setRecipient(string: String) {
    didInputRecipient(string)
    didUpdateRecipient?(string)
  }
  
  func setAmount(amount: BigUInt?) {
    self.item = self.item.setAmount(amount: amount ?? 0)
  }
  
  func setComment(comment: String?) {
    didInputComment(comment ?? "")
    didUpdateComment?(comment ?? "")
  }

  // MARK: - View State
  
  private var viewState: SendV3ViewModelViewState? {
    didSet {
      guard let viewState else { return }
      didUpdateViewState?(viewState)
    }
  }
  
  // MARK: - State

  private var comment: String?
  private var item: SendV3Item {
    didSet {
      didUpdateItem()
      updateViewState()
    }
  }
  private var recipient: Recipient?
  private var recipientInput = ""
  private var remaining: SendV3Controller.Remaining = .remaining("")
  private var converted = ""
  private var isAmountValid: Bool = false
  private var recipientResolvingTask: Task<Void, Never>?

  // MARK: - Formatters
  
  let sendAmountTextFieldFormatter: SendAmountTextFieldFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = Locale.current.groupingSeparator ?? " "
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
  private let buySellMethodsService: BuySellMethodsService
  
  // MARK: - Init
  
  init(wallet: Wallet,
       item: SendV3Item,
       recipient: Recipient?,
       comment: String?,
       sendController: SendV3Controller,
       balanceStore: ConvertedBalanceStore,
       appSettingsStore: AppSettingsStore,
       buySellMethodsService: BuySellMethodsService) {
    self.wallet = wallet
    self.comment = comment
    self.item = item
    self.recipient = recipient
    self.sendController = sendController
    self.balanceStore = balanceStore
    self.appSettingsStore = appSettingsStore
    self.buySellMethodsService = buySellMethodsService
  }
  
  func viewDidLoad() {
    balanceStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateConvertedBalance(let wallet):
        guard observer.wallet == wallet else { return }
        DispatchQueue.main.async {
          observer.recalculateOnBalanceUpdate()
        }
      }
    }
    
    sendAmountTextFieldFormatter.maximumFractionDigits = item.fractionalDigits
    didUpdateItem()
    didUpdateRecipientPlaceholder?(TKLocales.Send.Recepient.placeholder)
    didUpdateAmountPlaceholder?((TKLocales.Send.Amount.placeholder))
    if let recipient {
      didUpdateRecipient?(recipient.stringValue)
    }
    updateViewState()
    didUpdateAmount?(sendController.convertAmountToInputString(amount: item.amount, fractionDigits: item.fractionalDigits))
    
    if case let .ton(ton) = item, case .nft = ton {
      didUpdateAmountIsHidden?(true)
    }
  }
  
  func didInputRecipient(_ string: String) {
    guard string != recipientInput else { return }
    recipientInput = string
    recipient = nil
    recipientResolvingTask?.cancel()
    recipientResolvingTask = nil
    
    guard !string.isEmpty else {
      updateViewState()
      return
    }
    
    recipientResolvingTask = Task {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      do {
        guard !Task.isCancelled else { return }
        let recipient = try await sendController.resolveRecipient(input: string)
        guard !Task.isCancelled else { return }
        await MainActor.run {
          self.recipient = recipient
          self.recipientResolvingTask = nil
          self.updateViewState()
        }
      } catch {
        await MainActor.run {
          self.recipient = nil
          self.recipientResolvingTask = nil
          self.updateViewState()
        }
      }
    }
    
    updateViewState()
  }
  
  func didInputComment(_ string: String) {
    guard string != comment else { return }
    comment = string
    updateViewState()
  }
  
  func didInputAmount(_ string: String) {
    let unformatted = sendAmountTextFieldFormatter.unformatString(string) ?? ""
    let amount = sendController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: item.fractionalDigits)
    self.item = self.item.setAmount(amount: amount.amount)
  }
  
  func didTapWalletTokenPicker() {
    self.didTapPicker?(wallet, item)
  }
  
  func didTapRecipientPasteButton() {
    guard let pasteboardString = UIPasteboard.general.string else { return }
    didInputRecipient(pasteboardString)
    didUpdateRecipient?(pasteboardString)
  }
  
  func didTapCommentPasteButton() {
    guard let pasteboardString = UIPasteboard.general.string else { return }
    didInputComment(pasteboardString)
    didUpdateComment?(pasteboardString)
  }
  
  func didTapRecipientScanButton() {
    didTapScan?()
  }
  
  func didTapCloseButton() {
    didTapClose?()
  }
  
  func didTapMax() {
    switch item {
    case .ton(let ton):
      switch ton {
      case .nft: break
      case let .token(token, _):
        let maxAmount = sendController.getMaximumAmount(token: token)
        let formatted = sendController.convertAmountToInputString(amount: maxAmount, fractionDigits: token.fractionDigits)
        self.item = self.item.setAmount(amount: maxAmount)
        self.didUpdateAmount?(formatted)
      }
    case .tron(let tron):
      switch tron {
      case .usdt:
        let maxAmount = sendController.getTronUSDTMaximumAmount()
        let formatted = sendController.convertAmountToInputString(amount: maxAmount, fractionDigits: TronSwift.USDT.fractionDigits)
        self.item = self.item.setAmount(amount: maxAmount)
        self.didUpdateAmount?(formatted)
      }
    }
  }
  
  private func recalculateOnBalanceUpdate() {
    didUpdateItem()
    updateViewState()
  }
  
  private func updateTokenButton() {
    var name: String = ""
    var network: String?
    var image: TKImage = .image(nil)
    
    switch item {
    case .ton(let ton):
      switch ton {
      case .token(let token, _):
        switch token {
        case .ton:
          name = TonInfo.symbol
          image = .image(.TKCore.Icons.Size44.tonLogo)
        case .jetton(let item):
          name = item.jettonInfo.symbol ?? ""
          image = .urlImage(item.jettonInfo.imageURL)
        }
      case .nft: break
      }
    case .tron(let tron):
      switch tron {
      case .usdt:
        name = TronSwift.USDT.symbol
        image = .image(.App.Currency.Size44.usdt)
        network = "TRC20"
      }
    }
    
    didUpdateToken?(
      TokenPickerButton.Configuration(
        name: name,
        network: network,
        image: image
      )
    )
  }
  
  private func didUpdateItem() {
    let isAmountValid: Bool
    let remaining: SendV3Controller.Remaining
    let converted: String
    switch item {
    case .ton(let ton):
      switch ton {
      case .nft:
        isAmountValid = false
        remaining = .insufficient
        converted = ""
      case let .token(token, amount):
        isAmountValid = sendController.isAmountAvailableToSend(amount: amount, token: token)
        remaining = sendController.calculateRemaining(
          token: token,
          tokenAmount: amount,
          isSecure: appSettingsStore.getState().isSecureMode
        )
        converted = sendController.convertTokenAmountToCurrency(token: token, amount)
      }
    case .tron(let tron):
      switch tron {
      case .usdt(let amount):
        isAmountValid = sendController.isTronUSDTAmountAvailableToSend(amount: amount)
        remaining = sendController.calculateTronUSDTRemaining(
          amount: amount,
          isSecure: appSettingsStore.getState().isSecureMode
        )
        converted = sendController.convertTronUSDTAmountToCurrency(amount)
      }
    }
    
    self.isAmountValid = isAmountValid
    self.remaining = remaining
    self.converted = converted
    
    updateTokenButton()
  }
  
  private func updateViewState() {
    let isRecipientValid: Bool
    let isRecipientNotEmpty: Bool
    var recipientDescription: SendV3ViewModelViewState.RecipientDescription?
    
    if let recipient {
      switch item {
      case .ton:
        isRecipientValid = recipient.isTon
        if !recipient.isTon {
          recipientDescription = createIncorrectRecipientTRC20RecipientDescription()
        }
      case .tron:
        isRecipientValid = recipient.isTron
        if !recipient.isTron {
          recipientDescription = createIncorrectRecipientTonRecipientDescription()
        }
      }
      isRecipientNotEmpty = true
    } else {
      isRecipientValid = recipientInput.isEmpty || recipientResolvingTask != nil
      isRecipientNotEmpty = false
    }
    
    let balanceState: SendV3ViewModelViewState.BalanceState = {
      let remaining: SendV3ViewModelViewState.BalanceState.Remaining
      switch self.remaining {
      case .insufficient:
        remaining = .insufficient
      case .remaining(let string):
        remaining = .remaining(string)
      }
      return SendV3ViewModelViewState.BalanceState(converted: converted, remaining: remaining)
    }()
    
    let continueButtonConfiguration: TKButton.Configuration = {
      let isEnable = {
        let isItemValid = {
          switch item {
          case .ton(let item):
            switch item {
            case .nft:
              return true
            case .token:
              return isAmountValid
            }
          case .tron:
            return isAmountValid
          }
        }()
        
        return isRecipientValid && isRecipientNotEmpty && isItemValid && recipientResolvingTask == nil
      }()
      var configuration = TKButton.Configuration.actionButtonConfiguration(
        category: .primary,
        size: .large
      )
      configuration.isEnabled = isEnable
      configuration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.continueAction))
      configuration.action = { [weak self] in
        self?.continueAction()
      }
      return configuration
    }()
    
    let commentState: SendV3ViewModelViewState.CommentState = {
      let isCommentRequired = recipient?.isCommentRequired ?? false
      let comment = self.comment ?? ""
      let isCommentOk = self.sendController.validateComment(comment: comment)
      
      let isValid: Bool
      let description: NSAttributedString?
      let placeholder: String
      switch (isCommentRequired, comment.isEmpty, isCommentOk) {
      case (_, false, .ledgerNonAsciiError):
        isValid = false
        placeholder = TKLocales.Send.Comment.placeholder
        description = TKLocales.Send.Comment.asciiError.withTextStyle(
          .body2,
          color: .Accent.red,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        )
      case (false, true, _):
        isValid = true
        placeholder = TKLocales.Send.Comment.placeholder
        description = nil
      case (false, false, _):
        isValid = true
        placeholder = TKLocales.Send.Comment.placeholder
        description = TKLocales.Send.Comment.description.withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        )
      case (true, true, _):
        isValid = false
        placeholder = TKLocales.Send.RequiredComment.placeholder
        description = TKLocales.Send.RequiredComment.description
          .withTextStyle(
            .body2,
            color: .Accent.orange,
            alignment: .left,
            lineBreakMode: .byWordWrapping
          )
      case (true, false, _):
        isValid = true
        placeholder = TKLocales.Send.RequiredComment.placeholder
        description = TKLocales.Send.RequiredComment.description
          .withTextStyle(
            .body2,
            color: .Accent.orange,
            alignment: .left,
            lineBreakMode: .byWordWrapping
          )
      }
      
      return SendV3ViewModelViewState.CommentState(
        isValid: isValid,
        placeholder: placeholder,
        description: description
      )
    }()
    
    let viewState = SendV3ViewModelViewState(
      isRecipientValid: isRecipientValid,
      recipientDescription: recipientDescription,
      balanceState: balanceState,
      continueButtonConfiguration: continueButtonConfiguration,
      commentState: commentState
    )
    
    self.viewState = viewState
  }
  
  private func continueAction() {
    guard let data = SendData.sendData(
      wallet: wallet,
      recipient: recipient,
      item: item,
      comment: comment) else { return }
    didContinueSend?(data)
  }
  
  private var letsExchangeOpenTask: Task<Void, Never>?
  private func createIncorrectRecipientTRC20RecipientDescription() -> SendV3ViewModelViewState.RecipientDescription {
    let string = TKLocales.Send.IncorrectNetworkRecipient.trc20
      .replacingOccurrences(of: "NAME", with: "LetsExchange")
    return createIncorrectRecipientRecipientDescription(string: string)
  }
  private func createIncorrectRecipientTonRecipientDescription() -> SendV3ViewModelViewState.RecipientDescription {
    let string = TKLocales.Send.IncorrectNetworkRecipient.ton
      .replacingOccurrences(of: "NAME", with: "LetsExchange")
    return createIncorrectRecipientRecipientDescription(string: string)
  }
  private func createIncorrectRecipientRecipientDescription(string: String) -> SendV3ViewModelViewState.RecipientDescription {
    let result = string.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    ).mutableCopy() as! NSMutableAttributedString
    
    let letsExchangeRange = (string as NSString).range(of: "LetsExchange")
    result.addAttributes(
      [
        .foregroundColor: UIColor.Accent.blue.cgColor
      ],
      range: letsExchangeRange
    )
    return SendV3ViewModelViewState.RecipientDescription(
      description: result,
      actionItems: [TKActionLabel.ActionItem(
        text: "LetsExchange",
        action: { [weak self, buySellMethodsService] in
          self?.letsExchangeOpenTask?.cancel()
          self?.letsExchangeOpenTask = Task {
            guard let self else { return }
            func getLetsExchange(methods: FiatMethods) -> FiatMethodItem? {
              let allMethods = methods.buy.flatMap { $0.items }
              guard let method = allMethods.first(where: { $0.id == "letsexchange_buy_swap" }) else { return nil }
              return method
            }
            func getMethods() async -> FiatMethods? {
              if let methods = try? buySellMethodsService.getFiatMethods() {
                return methods
              } else if let methods = try? await buySellMethodsService.loadFiatMethods(countryCode: nil) {
                return methods
              } else {
                return nil
              }
            }
            guard let methods = await getMethods() else { return }
            guard !Task.isCancelled else { return }
            guard let method = getLetsExchange(methods: methods),
                  let url = URL(string: method.actionButton.url)  else { return }
            await MainActor.run {
              self.didOpenURL?(url)
            }
          }
        }
      )]
    )
  }
}

extension SendData {
  static func sendData(wallet: Wallet,
                       recipient: Recipient?,
                       item: SendV3Item,
                       comment: String?) -> SendData? {
    guard let recipient else { return nil }
    switch item {
    case .ton(let item):
      guard let recipient = recipient.tonRecipient else { return nil }
      return .ton(
        TonSendData(
          wallet: wallet,
          recipient: recipient,
          item: item,
          comment: comment
        )
      )
    case .tron(let item):
      guard let recipient = recipient.tronRecipient else { return nil }
      return .tron(
        TronSendData(
          wallet: wallet,
          recipient: recipient,
          item: item
        )
      )
    }
  }
}
