import Foundation
import BigInt
import TonSwift

public final class SendController {
  
  public var didUpdateFromWallets: (([SendWalletModel]) -> Void)?
  public var didUpdateSelectedFromWallet: ((Int) -> Void)?
  public var didUpdateToWallets: (([SendWalletModel]) -> Void)?
  public var didUpdateInputRecipient: ((SendRecipientModel) -> Void)?
  public var didUpdateIsSendAvailable: ((Bool) -> Void)?
  public var didUpdateAmount: (() -> Void)?
  public var didUpdateSendItem: (() -> Void)?
  public var didUpdateComment: (() -> Void)?
  
  struct SendWallet {
    let wallet: Wallet
    let balance: Balance?
    let activeToken: Token
  }
  
  enum SendRecipient {
    case inputRecipient
    case wallet(index: Int)
  }
  
  public struct SendWalletModel {
    public let id: String
    public let name: String
    public let tintColor: WalletTintColor
    public let balance: String?
    public let isPickerEnabled: Bool
  }
  
  public struct SendRecipientModel {
    public let value: String
    public let isEmpty: Bool
  }
  
  public enum SendItemModel {
    case token(value: String)
    case nft(nft: NFTModel)
  }
  
  // MARK: - State
  
  public private(set) var selectedFromWallet: Wallet
  public private(set) var selectedRecipient: Recipient?
  
  public private(set) var inputRecipient: Recipient? {
    didSet {
      didUpdateInputRecipient?(getInputRecipientModel())
      if inputRecipient != oldValue {
        self.selectedRecipient = inputRecipient
      }
      checkIfSendEnable()
    }
  }

  public private(set) var sendItem: SendItem {
    didSet {
      checkIfSendEnable()
      didUpdateSendItem?()
      reloadWallets()
    }
  }
  
  public private(set) var comment: String? {
    didSet {
      guard comment != oldValue else { return }
      checkIfSendEnable()
      didUpdateComment?()
    }
  }
  public private(set) var isSendAvailable = false {
    didSet {
      didUpdateIsSendAvailable?(isSendAvailable)
    }
  }
  
  private var isResolvingRecipient = false
  
  private var fromWallets = [Wallet]()
  private var toWallets = [Wallet]()
  
  private var fromWalletsTokens = [Wallet: Token]()

  // MARK: - Dependencies

  private let walletsStore: WalletsStore
  private let balanceStore: BalanceStore
  private let knownAccountsStore: KnownAccountsStore
  private let dnsService: DNSService
  private let amountFormatter: AmountFormatter
  
  // MARK: - Init
  
  init(sendItem: SendItem,
       recipient: Recipient?,
       walletsStore: WalletsStore,
       balanceStore: BalanceStore,
       knownAccountsStore: KnownAccountsStore,
       dnsService: DNSService,
       amountFormatter: AmountFormatter) {
    self.sendItem = sendItem
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.knownAccountsStore = knownAccountsStore
    self.dnsService = dnsService
    self.amountFormatter = amountFormatter
    self.selectedFromWallet = walletsStore.activeWallet
    
    if let recipient {
      inputRecipient = recipient
    }
  }
  
  public func start() {
    didUpdateInputRecipient?(getInputRecipientModel())
    reloadWallets()
    didUpdateComment?()
    didUpdateSendItem?()
  }
  
  public func setInputRecipient(with input: String) {
    self.isResolvingRecipient = true
    Task {
      let inputRecipient: Recipient?
      let knownAccounts = (try? await knownAccountsStore.getKnownAccounts()) ?? []
      if let friendlyAddress = try? FriendlyAddress(string: input) {
        inputRecipient = Recipient(
          recipientAddress: .friendly(
            friendlyAddress
          ),
          isMemoRequired: knownAccounts.first(where: { $0.address == friendlyAddress.address })?.requireMemo ?? false
        )
      } else if let rawAddress = try? Address.parse(input) {
        inputRecipient = Recipient(
          recipientAddress: .raw(
            rawAddress
          ),
          isMemoRequired: knownAccounts.first(where: { $0.address == rawAddress })?.requireMemo ?? false
        )
      } else if let domain = try? await dnsService.resolveDomainName(input, isTestnet: false) {
        inputRecipient = Recipient(
          recipientAddress: .domain(domain),
          isMemoRequired: knownAccounts.first(where: { $0.address == domain.friendlyAddress.address })?.requireMemo ?? false
        )
      } else {
        inputRecipient = nil
      }
      await MainActor.run {
        self.isResolvingRecipient = false
        self.inputRecipient = inputRecipient
      }
    }
  }
  
  public func setInputRecipient(_ recipient: Recipient?) {
    self.inputRecipient = recipient
  }
  
  public func setSendItem(_ sendItem: SendItem) {
    self.sendItem = sendItem
  }

  public func setComment(_ comment: String?) {
    self.comment = comment
  }

  public func getInputRecipientModel() -> SendRecipientModel {
    guard let inputRecipient = inputRecipient else {
      return SendRecipientModel(value: "Address or name", isEmpty: true)
    }
    switch inputRecipient.recipientAddress {
    case .friendly(let friendlyAddress):
      return SendRecipientModel(value: friendlyAddress.toString(), isEmpty: false)
    case .raw(let address):
      return SendRecipientModel(value: address.toRaw(), isEmpty: false)
    case .domain(let domainRecipient):
      return SendRecipientModel(value: domainRecipient.domain, isEmpty: false)
    }
  }
  
  public func getSendItemModel() -> SendItemModel {
    switch sendItem {
    case .token(let token, let amount):
      let value: String
      switch token {
      case .ton:
        value = amountFormatter.formatAmount(
          amount,
          fractionDigits: TonInfo.fractionDigits,
          maximumFractionDigits: TonInfo.fractionDigits,
          symbol: TonInfo.symbol
        )
      case .jetton(let jettonItem):
        value = amountFormatter.formatAmount(
          amount,
          fractionDigits: jettonItem.jettonInfo.fractionDigits,
          maximumFractionDigits: jettonItem.jettonInfo.fractionDigits,
          symbol: jettonItem.jettonInfo.symbol
        )
      }
      return .token(value: value)
    case .nft(let nft):
      return .nft(nft: NFTModel(nft: nft))
    }
  }

  public func getComment() -> String? {
    comment
  }
  
  public func setWalletSelectedSender(index: Int) {
    guard fromWallets.count > index else { return }
    selectedFromWallet = fromWallets[index]
    reloadToWallets()
    checkIfSendEnable()
  }
  
  public func setWalletSelectedRecipient(index: Int) {
    guard toWallets.count > index else { return }
    do {
      let address = try toWallets[index].address.toFriendly(bounceable: false)
      selectedRecipient = Recipient(recipientAddress: .friendly(address), isMemoRequired: false)
    } catch {
      selectedRecipient = nil
    }
    checkIfSendEnable()
  }
  
  public func setInputRecipientSelectedRecipient() {
    selectedRecipient = inputRecipient
    checkIfSendEnable()
  }
}

private extension SendController {
  func reloadWallets() {
    reloadFromWallets()
    reloadToWallets()
    checkIfSendEnable()
  }

  func reloadFromWallets() {
    switch sendItem {
    case .nft:
      fromWallets = [walletsStore.activeWallet]
    case .token(let token, _):
      fromWallets = walletsStore.wallets
        .filter {
          $0.isSendAvailable
        }
        .filter { wallet in
        switch token {
        case .ton:
          return true
        case .jetton(let jettonItem):
          let balance = (try? balanceStore.getBalance(wallet: wallet))?.balance ?? Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
          return balance.jettonsBalance.contains(where: { $0.item.jettonInfo == jettonItem.jettonInfo })
        }
      }
    }
    guard !fromWallets.isEmpty else { return }
    selectedFromWallet = fromWallets.first(where: { $0 == selectedFromWallet }) ?? fromWallets[0]

    let models = fromWallets.map { wallet in
      let balance: Balance?
      let isTokenPickerRequired: Bool
      switch sendItem {
      case .nft:
        balance = nil
        isTokenPickerRequired = false
      case .token:
        balance = getWalletBalance(wallet: wallet)
        isTokenPickerRequired = true
      }
      return createWalletModel(wallet: wallet, balance: balance, isTokenPickerRequired: isTokenPickerRequired)
    }
    didUpdateFromWallets?(models)
    
    if let activeWalletIndex = fromWallets.firstIndex(of: selectedFromWallet) {
      self.didUpdateSelectedFromWallet?(activeWalletIndex)
    }
  }
  
  func reloadToWallets() {
    toWallets = walletsStore.wallets
    
    let models = toWallets.map { wallet in
      let balance: Balance?
      switch sendItem {
      case .nft:
        balance = nil
      case .token:
        balance = getWalletBalance(wallet: wallet)
      }
      return createWalletModel(wallet: wallet, balance: balance, isTokenPickerRequired: false)
    }
    didUpdateToWallets?(models)
  }

  func checkIfSendEnable() {
    let isRecipientValid: Bool = {
      switch selectedRecipient?.recipientAddress {
      case .none: return false
      default: return true
      }
    }()
    
    let isSendItemValid: Bool = {
      switch sendItem {
      case .nft:
        return true
      case .token(let token, let amount):
        guard !amount.isZero else { return false }
        let balance: Balance
        do {
          balance = try balanceStore.getBalance(wallet: selectedFromWallet).balance
        } catch {
          balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
        }
        switch token {
        case .ton:
          return BigUInt(balance.tonBalance.amount) >= amount
        case .jetton(let jettonItem):
          let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
          return jettonBalance >= amount
        }
      }
    }()
    
    let isCommentValid: Bool = {
      guard let selectedRecipient else { return false }
      return !selectedRecipient.isMemoRequired || !(comment ?? "").isEmpty
    }()
    
    let isValid = isRecipientValid && isSendItemValid && isCommentValid
    self.isSendAvailable = isValid
  }

  func createWalletModel(wallet: Wallet, balance: Balance?, isTokenPickerRequired: Bool) -> SendWalletModel {
    let name = "\(wallet.emoji)\(wallet.label)"
    let balanceValue: String?
    let isPickerEnabled: Bool
    switch sendItem {
    case .nft:
      balanceValue = nil
      isPickerEnabled = false
    case .token(let token, _):
      guard let balance else {
        balanceValue = nil
        isPickerEnabled = false
        break
      }
      switch token {
      case .ton:
        balanceValue = amountFormatter.formatAmount(
          BigUInt(integerLiteral: UInt64(balance.tonBalance.amount)),
          fractionDigits: TonInfo.fractionDigits,
          maximumFractionDigits: 2,
          symbol: TonInfo.symbol
        )
        isPickerEnabled = !balance.jettonsBalance.isEmpty && isTokenPickerRequired
      case .jetton(let jettonItem):
        let amount: BigUInt
        if let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo }) {
          amount = jettonBalance.quantity
        } else {
          amount = 0
        }
        balanceValue = amountFormatter.formatAmount(
          amount,
          fractionDigits: jettonItem.jettonInfo.fractionDigits,
          maximumFractionDigits: 2,
          symbol: jettonItem.jettonInfo.symbol
        )
        isPickerEnabled = isTokenPickerRequired
      }
      
    }
    return SendWalletModel(
      id: UUID().uuidString,
      name: name,
      tintColor: wallet.tintColor,
      balance: balanceValue,
      isPickerEnabled: isPickerEnabled
    )
  }
  
  func getWalletBalance(wallet: Wallet) -> Balance? {
    let balance: Balance?
    switch sendItem {
    case .nft:
      balance = nil
    case .token:
      do {
        balance = try balanceStore.getBalance(wallet: wallet).balance
      } catch {
        balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
      }
    }
    return balance
  }
}
