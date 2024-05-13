import Foundation
import BigInt

public final class BuySellController {
  private let locationService: LocationService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let amountFormatter: AmountFormatter
  
  init(locationService: LocationService,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       amountFormatter: AmountFormatter) {
    self.locationService = locationService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
  }
  
  public func start() async {
    
  }
  
  public func getCountryCode() async -> String? {
    return try? await locationService.getCountryCodeByIp()
  }
  
  public func getActiveCurrency() async -> Currency {
    return await currencyStore.getActiveCurrency()
  }
  
  public func convertTokenAmountToCurrency(token: Token, _ amount: BigUInt, currency: Currency) async -> String {
    guard !amount.isZero else { return "0" }
    switch token {
    case .ton:
      guard let rate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency }) else { return "" }
      let converted = RateConverter().convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
      let formatted = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2
      )
      return formatted
    case .jetton:
//      let wallet = walletsStore.activeWallet
//      do {
//        let balance = try await walletBalanceStore.getBalanceState(walletAddress: try wallet.address)
//        guard let jettonBalance = balance.walletBalance.balance.jettonsBalance.first(where: {
//          $0.item.jettonInfo == jettonItem.jettonInfo
//        }) else { return "" }
//
//        guard let rate = jettonBalance.rates[currency] else { return ""}
//        let converted = RateConverter().convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
//        let formatted = amountFormatter.formatAmount(
//          converted.amount,
//          fractionDigits: converted.fractionLength,
//          maximumFractionDigits: 2,
//          currency: currency
//        )
//        return "≈ \(formatted)"
//      } catch {
//        return ""
//      }
      return ""
    }
  }
  
  public func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (value: BigUInt, fractionalDigits: Int) {
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
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}
