import Foundation
import TonSwift
import BigInt

public final class SwapItemsController {
  
  private let swapService: any SwapService
  private let assetsStore: AssetsStore
  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let knownAccountsStore: KnownAccountsStore
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let amountFormatter: AmountFormatter
  
  init(
    swapService: any SwapService,
    assetsStore: AssetsStore,
    walletsStore: WalletsStore,
    walletBalanceStore: WalletBalanceStore,
    knownAccountsStore: KnownAccountsStore,
    tonRatesStore: TonRatesStore,
    currencyStore: CurrencyStore,
    amountFormatter: AmountFormatter) {
      self.swapService = swapService
      self.assetsStore = assetsStore
      self.walletsStore = walletsStore
      self.walletBalanceStore = walletBalanceStore
      self.knownAccountsStore = knownAccountsStore
      self.tonRatesStore = tonRatesStore
      self.currencyStore = currencyStore
      self.amountFormatter = amountFormatter
  }

  public func loadAssets() async throws -> [Asset]  {
    return await assetsStore.getAssets() ?? []
  }
  public func loadPairs() async throws -> [String: [String]]?  {
    return await assetsStore.getPairs()
  }
  public func swapEstimate(offerAddress: String, askAddress: String, units: BigUInt, slippageTolerance: Float) async throws -> SwapEstimate  {
    return try await swapService.swapSimulate(offerAddress: offerAddress,
                                              askAddress: askAddress,
                                              units: "\(units)",
                                              slippageTolerance: slippageTolerance)
  }
  public func reverseSwapEstimate(offerAddress: String,
                                  askAddress: String,
                                  units: BigUInt,
                                  slippageTolerance: Float) async throws -> SwapEstimate  {
    return try await swapService.reverseSwapSimulate(offerAddress: offerAddress,
                                                     askAddress: askAddress,
                                                     units: "\(units)",
                                                     slippageTolerance: slippageTolerance)
  }
  
  public var wallet: Wallet {
    walletsStore.activeWallet
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
  
  public func convertAmountToInputString(amount: BigUInt, token: SwapToken) -> String {
    let tokenFractionDigits: Int
    switch token {
    case .ton:
      tokenFractionDigits = TonInfo.fractionDigits
    case .jetton(let jettonItem):
      tokenFractionDigits = jettonItem.decimals
    }
    let formatted = amountFormatter.formatAmount(
      amount,
      fractionDigits: tokenFractionDigits,
      maximumFractionDigits: tokenFractionDigits
    )
    return formatted
  }
  
  public func getAmountAvailable(symbol: String) async -> BigUInt {
    let wallet = walletsStore.activeWallet
    do {
      let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
      switch symbol {
      case "TON":
        return BigUInt(balance.walletBalance.balance.tonBalance.amount)
      default:
        return balance.walletBalance.balance.jettonsBalance.first(where: { $0.item.jettonInfo.symbol == symbol })?.quantity ?? 0
      }
    } catch {
      return .zero
    }
  }
  
  public func isAmountAvailableToSend(amount: BigUInt, symbol: String) async -> Bool {
    let wallet = walletsStore.activeWallet
    do {
      let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
      switch symbol {
      case "TON":
        return BigUInt(balance.walletBalance.balance.tonBalance.amount) >= amount
      default:
        let jettonBalanceAmount = balance.walletBalance.balance.jettonsBalance.first(where: { $0.item.jettonInfo.symbol == symbol })?.quantity ?? 0
        return jettonBalanceAmount >= amount
      }
    } catch {
      return false
    }
  }
  
  public func convertTokenAmountToCurrency(token: Token, _ amount: BigUInt) async -> String {
    guard !amount.isZero else { return "" }
    let currency = await currencyStore.getActiveCurrency()
    switch token {
    case .ton:
      guard let rate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency }) else { return ""}
      let converted = RateConverter().convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
      let formatted = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
      return "≈ \(formatted)"
    case .jetton(let jettonItem):
      let wallet = walletsStore.activeWallet
      do {
        let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
        guard let jettonBalance = balance.walletBalance.balance.jettonsBalance.first(where: {
          $0.item.jettonInfo == jettonItem.jettonInfo
        }) else { return "" }
        
        guard let rate = jettonBalance.rates[currency] else { return ""}
        let converted = RateConverter().convert(amount: amount, amountFractionLength: jettonItem.jettonInfo.fractionDigits, rate: rate)
        let formatted = amountFormatter.formatAmount(
          converted.amount,
          fractionDigits: converted.fractionLength,
          maximumFractionDigits: 2,
          currency: currency
        )
        return "≈ \(formatted)"
      } catch {
        return ""
      }
    }
  }
  
  public enum Remaining {
    case insufficient
    case remaining(String)
  }
  public func calculateRemaining(token: Token, tokenAmount: BigUInt) async -> Remaining {
    let wallet = walletsStore.activeWallet
    let amount: BigUInt
    let tokenSymbol: String?
    let fractionalDigits: Int
    do {
      let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
      switch token {
      case .ton:
        amount = BigUInt(balance.walletBalance.balance.tonBalance.amount)
        fractionalDigits = TonInfo.fractionDigits
        tokenSymbol = TonInfo.symbol
      case .jetton(let jettonItem):
        amount = balance.walletBalance.balance.jettonsBalance.first(where: {
          $0.item.jettonInfo == jettonItem.jettonInfo
        })?.quantity ?? 0
        fractionalDigits = jettonItem.jettonInfo.fractionDigits
        tokenSymbol = jettonItem.jettonInfo.symbol
      }
    } catch {
      return .insufficient
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
    let wallet = walletsStore.activeWallet
    do {
      let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
      switch token {
      case .ton:
        return BigUInt(balance.walletBalance.balance.tonBalance.amount)
      case .jetton(let jettonItem):
        return balance.walletBalance.balance.jettonsBalance.first(where: {
          $0.item.jettonInfo == jettonItem.jettonInfo
        })?.quantity ?? 0
      }
    } catch {
      return .zero
    }
  }
  
  public func isPairValid(sellingContract: String, buyingContract: String) async -> Bool {
    let pairs = try? await loadPairs()
    return pairs?[sellingContract]?.contains(where: { peer2 in
      peer2 == buyingContract
    }) ?? false
  }
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}
