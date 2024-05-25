import Foundation
import BigInt
import TonSwift

public final class SwapController {

  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let ratesService: RatesService
  private let amountFormatter: AmountFormatter
  
  init(walletsStore: WalletsStore,
       walletBalanceStore: WalletBalanceStore,
       ratesService: RatesService,
       amountFormatter: AmountFormatter) {
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.ratesService = ratesService
    self.amountFormatter = amountFormatter
  }
  
  public func calculateReceiveRate(
    sendToken: Token,
    amount: BigUInt,
    receiveToken: Token
  ) async throws -> BigUInt {
    if amount == 0 { return 0 }
    let jettons: [JettonInfo] = [sendToken, receiveToken].compactMap {
      if case .jetton(let jettonItem) = $0 { return jettonItem.jettonInfo } else { return nil }
    }
    let rates = try await ratesService.loadRates(jettons: jettons, currencies: [.TON])
    let tonSendRate = getTonRate(for: sendToken, tonRates: rates.ton, jettonRates: rates.jettonsRates)
    let tonReceiveRate = getTonRate(for: receiveToken, tonRates: rates.ton, jettonRates: rates.jettonsRates)
    let converter = RateConverter()
    let converted = converter.convert(amount: amount, amountFractionLength: sendToken.tokenFractionalDigits, rate: tonSendRate / tonReceiveRate)
    
    let convertedPlainString = String(converted.amount)
    let symbols = (convertedPlainString.count - converted.fractionLength) + receiveToken.tokenFractionalDigits
    let final = convertedPlainString[..<convertedPlainString.index(convertedPlainString.startIndex, offsetBy: symbols)]
    return BigUInt(stringLiteral: String(final))
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

  // TODO: Refactor it
  // Copy-pasted from SendV3Controller
  // There are lots of common logic, that might be moved to a separate common controller or to Service layer
  // Tried the approach with a separate common controller, but got stuck, so sorry for a tech debt here

  public func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    guard !input.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = amountFormatter.fractionalSeparator
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

  public func isAmountAvailableToSend(amount: BigUInt, token: Token) async -> Bool {
    let wallet = walletsStore.activeWallet
    do {
      let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
      switch token {
      case .ton:
        return BigUInt(balance.walletBalance.balance.tonBalance.amount) >= amount
      case .jetton(let jettonItem):
        let jettonBalanceAmount = balance.walletBalance.balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
        return jettonBalanceAmount >= amount
      }
    } catch {
      return false
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
}

private extension SwapController {
  private func getTonRate(
    for token: Token,
    tonRates: [Rates.Rate],
    jettonRates: [Rates.JettonRate]
  ) -> Decimal {
    switch token {
    case .ton:
      return tonRates.first { $0.currency == .TON }?.rate ?? 0
    case .jetton(let item):
      return jettonRates.first { $0.jettonInfo == item.jettonInfo }?.rates.first { $0.currency == .TON }?.rate ?? 0
    }
  }
}
