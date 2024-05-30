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
  
  public func convertAmountToString(amount: BigUInt, fractionDigits: Int) -> String {
    return amountNewFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits,
      currency: nil
    )
  }
  
  public func convertStringToAmount(string: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    return amountNewFormatter.amount(
      from: string,
      targetFractionalDigits: targetFractionalDigits
    )
  }
  
  public func convertTokenToFiat(_ token: BuySellItem.Token, currency: Currency) async -> BuySellItem.Fiat {
    let tonRate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency })
    let rate = tonRate ?? Rates.Rate(currency: currency, rate: 0, diff24h: nil)
    
    let converted = convertAmount(
      amount: token.amount,
      usingRate: rate,
      amountFractionLength: token.fractionDigits,
      targetFractionLenght: 2
    )
    
    return BuySellItem.Fiat(
      amount: converted.amount,
      amountString: converted.string,
      currency: currency
    )
  }
  
  public func convertFiatToToken(_ fiat: BuySellItem.Fiat, token: BuySellModel.Token) async -> BuySellItem.Token {
    let currency = fiat.currency
    let tonRate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency })
    var rate = tonRate ?? Rates.Rate(currency: currency, rate: 0, diff24h: nil)
    
    if !rate.rate.isZero {
      rate = Rates.Rate(
        currency: rate.currency,
        rate: 1 / rate.rate,
        diff24h: rate.diff24h
      )
    }
    
    let converted = convertAmount(
      amount: fiat.amount,
      usingRate: rate,
      amountFractionLength: 2,
      targetFractionLenght: token.fractionDigits
    )
    
    return BuySellItem.Token(
      amount: converted.amount,
      amountString: converted.string,
      token: token
    )
  }
}

private extension BuySellController {
  func convertAmount(amount: BigUInt,
                     usingRate rate: Rates.Rate,
                     amountFractionLength: Int,
                     targetFractionLenght: Int) -> (amount: BigUInt, string: String) {
    let converted = RateConverter().convert(
      amount: amount,
      amountFractionLength: amountFractionLength,
      rate: rate
    )
    let convertedAmount = truncateAmountFractionLenght(
      amount: converted.amount,
      currentLenght: converted.fractionLength,
      targetLenght: targetFractionLenght
    )
    let convertedString = amountNewFormatter.formatAmount(
      convertedAmount,
      fractionDigits: targetFractionLenght,
      maximumFractionDigits: targetFractionLenght
    )
    return (convertedAmount, convertedString)
  }
  
  func truncateAmountFractionLenght(amount: BigUInt, currentLenght: Int, targetLenght: Int) -> BigUInt {
    guard currentLenght > targetLenght else { return amount }
    let digitsToRemove = currentLenght - targetLenght
    let divisor = BigUInt(10).power(digitsToRemove)
    return amount / divisor
  }
}
