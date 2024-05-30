import Foundation
import BigInt
import TonSwift

public final class SwapController {

  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let ratesService: RatesService
  private let amountFormatter: AmountFormatter
  private let currencyStore: CurrencyStore
  
  init(walletsStore: WalletsStore,
       walletBalanceStore: WalletBalanceStore,
       ratesService: RatesService,
       amountFormatter: AmountFormatter,
       currencyStore: CurrencyStore) {
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.ratesService = ratesService
    self.amountFormatter = amountFormatter
    self.currencyStore = currencyStore
  }

  public var groupSeparatorForFormatting: String {
    amountFormatter.groupSeparator
  }
  
  public func calculateReceiveRate(
    sendToken: Token,
    amount: BigUInt,
    receiveToken: Token,
    priceChangeLimit: Double
  ) async throws -> (expected: BigUInt, minimum: BigUInt) {
    if amount == 0 { return (0, 0) }
    let jettons: [JettonInfo] = [sendToken, receiveToken].compactMap {
      if case .jetton(let jettonItem) = $0 { return jettonItem.jettonInfo } else { return nil }
    }
    let rates = try await ratesService.loadRates(jettons: jettons, currencies: [.TON])
    let tonSendRate = getRate(for: sendToken, currency: .TON, tonRates: rates.ton, jettonRates: rates.jettonsRates)
    let tonReceiveRate = getRate(for: receiveToken, currency: .TON, tonRates: rates.ton, jettonRates: rates.jettonsRates)
    let converter = RateConverter()
    let converted = converter.convert(amount: amount, amountFractionLength: sendToken.tokenFractionalDigits, rate: tonSendRate / tonReceiveRate)
    let minimumRate = (tonSendRate / tonReceiveRate) * (100 - Decimal(priceChangeLimit * 100)) / 100
    let convertedMinimum = converter.convert(amount: amount, amountFractionLength: sendToken.tokenFractionalDigits, rate: minimumRate)
    
    return (
      BigUInt(stringLiteral: getStringForConverted(converted, receiveToken: receiveToken)),
      BigUInt(stringLiteral: getStringForConverted(convertedMinimum, receiveToken: receiveToken))
    )
  }

  public func convertOneTokenAmountToCurrency(token: Token) async throws -> String {
    let amount = BigUInt(stringLiteral: "1" + String(repeating: "0", count: token.tokenFractionalDigits))
    let converted = try await convertTokenAmountToCurrency(token: token, amount)
    return "1 \(token.symbol ?? "token") ≈ \(converted)"
  }

  public func convertTokenAmountToCurrency(token: Token, _ amount: BigUInt) async throws -> String {
    let currency = await currencyStore.getActiveCurrency()
    let jettons: [JettonInfo] = [token].compactMap {
      if case .jetton(let jettonItem) = $0 { return jettonItem.jettonInfo } else { return nil }
    }
    let rates = try await ratesService.loadRates(jettons: jettons, currencies: [currency])
    let rate = getRate(for: token, currency: currency, tonRates: rates.ton, jettonRates: rates.jettonsRates)
    let converted = RateConverter().convert(amount: amount, amountFractionLength: token.tokenFractionalDigits, rate: rate)
    let formatted = amountFormatter.formatAmount(
      converted.amount,
      fractionDigits: converted.fractionLength,
      maximumFractionDigits: 2,
      currency: currency
    )
    return formatted
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
  // Initially copy-pasted from SendV3Controller
  // There are lots of common logic, that might be moved to a separate common controller or to Service layer
  // Tried the approach with a separate common controller, but got stuck, so sorry for a tech debt here

  public func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    guard !input.isEmpty else { return (0, targetFractionalDigits) }

    let fractionalSeparator: String = amountFormatter.fractionalSeparator

    let allowedCharacters = CharacterSet(charactersIn: "0123456789" + fractionalSeparator + amountFormatter.groupSeparator)
    let prohibitedSymbols = input.unicodeScalars.filter { !allowedCharacters.contains($0) }
    if !prohibitedSymbols.isEmpty {
      return (0, targetFractionalDigits)
    }

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
  private func getRate(
    for token: Token,
    currency: Currency,
    tonRates: [Rates.Rate],
    jettonRates: [Rates.JettonRate]
  ) -> Decimal {
    switch token {
    case .ton:
      return tonRates.first { $0.currency == currency }?.rate ?? 0
    case .jetton(let item):
      return jettonRates.first { $0.jettonInfo == item.jettonInfo }?.rates.first { $0.currency == currency }?.rate ?? 0
    }
  }

  private func getStringForConverted(_ converted: (amount: BigUInt, fractionLength: Int), receiveToken: Token) -> String {
    let convertedPlainString = String(converted.amount)
    let symbols = (convertedPlainString.count - converted.fractionLength) + receiveToken.tokenFractionalDigits
    let final = convertedPlainString[..<convertedPlainString.index(convertedPlainString.startIndex, offsetBy: symbols)]
    return String(final)
  }
}
