import Foundation
import TonSwift
import BigInt

public final class SendV3Controller {
  private let wallet: Wallet
  private let balanceStore: ConvertedBalanceStoreV3
  private let knownAccountsStore: KnownAccountsStore
  private let dnsService: DNSService
  private let tonRatesStore: TonRatesStoreV3
  private let currencyStore: CurrencyStoreV3
  private let amountFormatter: AmountFormatter
  
  init(wallet: Wallet,
       balanceStore: ConvertedBalanceStoreV3,
       knownAccountsStore: KnownAccountsStore,
       dnsService: DNSService,
       tonRatesStore: TonRatesStoreV3,
       currencyStore: CurrencyStoreV3,
       amountFormatter: AmountFormatter) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.knownAccountsStore = knownAccountsStore
    self.dnsService = dnsService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
  }
  
  public func resolveRecipient(input: String) async -> Recipient? {
    let knownAccounts: [KnownAccount]
    do {
      knownAccounts = try await knownAccountsStore.getKnownAccounts()
    } catch {
      knownAccounts = []
    }
    
    if let friendlyAddress = try? FriendlyAddress(string: input) {
      return (Recipient(recipientAddress: .friendly(friendlyAddress),
                        isMemoRequired: knownAccounts.first(where: { $0.address == friendlyAddress.address })?.requireMemo ?? false))
    } else if let rawAddress = try? Address.parse(input) {
      return (Recipient(recipientAddress: .raw(rawAddress),
                        isMemoRequired: knownAccounts.first(where: { $0.address == rawAddress })?.requireMemo ?? false))
    } else if let domain = try? await dnsService.resolveDomainName(
      input,
      isTestnet: wallet.isTestnet) {
      return Recipient(recipientAddress: .domain(domain),
                       isMemoRequired: knownAccounts.first(where: { $0.address == domain.friendlyAddress.address })?.requireMemo ?? false)
    } else {
      return nil
    }
  }
  
  public func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    guard !input.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = input.components(separatedBy: fractionalSeparator)
    guard components.count < 3 else {
      return (0, targetFractionalDigits)
    }
    
    var fractionalDigits = 0
    if components.count == 2 {
      let fractionalString = components[1]
      fractionalDigits = fractionalString.count
    }
    let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
    let bigIntValue = BigUInt(stringLiteral: components.joined() + zeroString)
    return (bigIntValue, targetFractionalDigits)
  }
  
  public func convertAmountToInputString(amount: BigUInt, token: Token) -> String {
    let tokenFractionDigits: Int
    switch token {
    case .ton:
      tokenFractionDigits = TonInfo.fractionDigits
    case .jetton(let jettonItem):
      tokenFractionDigits = jettonItem.jettonInfo.fractionDigits
    }
    let formatted = amountFormatter.formatAmount(
      amount,
      fractionDigits: tokenFractionDigits,
      maximumFractionDigits: tokenFractionDigits
    )
    return formatted
  }
  
  public func isAmountAvailableToSend(amount: BigUInt, token: Token) async -> Bool {
    guard let balance = await balanceStore.getState()[wallet]?.balance else { return false }
    switch token {
    case .ton:
      return BigUInt(balance.tonBalance.tonBalance.amount) >= amount
    case .jetton(let jettonItem):
      let jettonBalanceAmount = balance.jettonsBalance.first(where: { $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo })?.jettonBalance.quantity ?? 0
      return jettonBalanceAmount >= amount
    }
  }
  
  public func convertTokenAmountToCurrency(token: Token, _ amount: BigUInt) async -> String {
    guard !amount.isZero else { return "" }
    let currency = await currencyStore.getState()
    switch token {
    case .ton:
      guard let rate = await tonRatesStore.getState().first(where: { $0.currency == currency }) else { return ""}
      let converted = RateConverter().convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
      let formatted = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
      return "≈ \(formatted)"
    case .jetton(let jettonItem):
      guard let jettonRate = await balanceStore.getState()[wallet]?.balance.jettonsBalance
        .first(where: { $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo })?
        .jettonBalance.rates[currency]  else {
        return ""
      }
      
      let converted = RateConverter().convert(
        amount: amount,
        amountFractionLength: jettonItem.jettonInfo.fractionDigits,
        rate: jettonRate
      )
      let formatted = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
      return "≈ \(formatted)"
    }
  }
  
  public enum Remaining {
    case insufficient
    case remaining(String)
  }
  public func calculateRemaining(token: Token, tokenAmount: BigUInt) async -> Remaining {
    guard let balance = await balanceStore.getState()[wallet]?.balance else {
      return .insufficient
    }
    let amount: BigUInt
    let tokenSymbol: String?
    let fractionalDigits: Int
    switch token {
    case .ton:
      amount = BigUInt(balance.tonBalance.tonBalance.amount)
      fractionalDigits = TonInfo.fractionDigits
      tokenSymbol = TonInfo.symbol
    case .jetton(let jettonItem):
      amount = balance.jettonsBalance.first(where: {
        $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo
      })?.jettonBalance.quantity ?? 0
      fractionalDigits = jettonItem.jettonInfo.fractionDigits
      tokenSymbol = jettonItem.jettonInfo.symbol
    }
    
    if amount >= tokenAmount {
      let remainingAmount = amount - tokenAmount
      let formatted = amountFormatter.formatAmount(
        remainingAmount,
        fractionDigits: fractionalDigits,
        maximumFractionDigits: fractionalDigits,
        symbol: tokenSymbol
      )
      return .remaining(formatted)
    } else {
      return .insufficient
    }
  }
  
  public func getMaximumAmount(token: Token) async -> BigUInt {
    guard let balance = await balanceStore.getState()[wallet]?.balance else {
      return .zero
    }
    switch token {
    case .ton:
      return BigUInt(balance.tonBalance.tonBalance.amount)
    case .jetton(let jettonItem):
      return balance.jettonsBalance.first(where: {
        $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo
      })?.jettonBalance.quantity ?? 0
    }
  }
  
  public enum CommentState {
    case ledgerNonAsciiError
    case ok
  }
  public func validateComment(comment: String) -> CommentState {
    if (wallet.kind == .ledger && comment.count > 0 && !comment.containsOnlyAsciiCharacters) {
      return .ledgerNonAsciiError
    }
    
    return .ok
  }
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
  var containsOnlyAsciiCharacters: Bool {
    let pattern = "^[\\x20-\\x7E]*$"
    do {
      let regex = try NSRegularExpression(pattern: pattern)
      let range = NSRange(location: 0, length: self.utf16.count)
      let match = regex.firstMatch(in: self, options: [], range: range)
      return match != nil
    } catch {
      print("Invalid regular expression: \(error.localizedDescription)")
      return false
    }
  }
}
