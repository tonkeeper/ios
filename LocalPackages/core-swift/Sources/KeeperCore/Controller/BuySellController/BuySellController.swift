import Foundation
import BigInt

public final class BuySellController {
  
  private let locationService: LocationService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let amountNewFormatter: AmountNewFormatter
  
  init(locationService: LocationService,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       amountNewFormatter: AmountNewFormatter) {
    self.locationService = locationService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.amountNewFormatter = amountNewFormatter
  }
  
  public func getCountryCode() async -> String? {
    return try? await locationService.getCountryCodeByIp()
  }
  
  public func getActiveCurrency() async -> Currency {
    return await currencyStore.getActiveCurrency()
  }
  
  public func convertTokenAmountToCurrency(token: BuySellModel.Token, amount: BigUInt, currency: Currency) async -> String {
    guard !amount.isZero else { return "0" }
    guard let rate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency }) else { return "0" }
    let converted = RateConverter().convert(amount: amount, amountFractionLength: token.fractionDigits, rate: rate)
    return amountNewFormatter.formatAmount(
      converted.amount,
      fractionDigits: converted.fractionLength,
      maximumFractionDigits: 2
    )
  }
  
  public func convertAmountToString(amount: BigUInt, fractionDigits: Int) -> String {
    return amountNewFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits,
      currency: nil
    )
  }
  
  public func convertStringToAmount(string: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    return amountNewFormatter.amount(from: string, targetFractionalDigits: targetFractionalDigits)
  }
}
