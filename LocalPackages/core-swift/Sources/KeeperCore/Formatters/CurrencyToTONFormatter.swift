import Foundation
import TKLocalize

public struct CurrencyToTONFormatter {
  private let decimalAmountFormatter: DecimalAmountFormatter
  
  public init(decimalAmountFormatter: DecimalAmountFormatter) {
    self.decimalAmountFormatter = decimalAmountFormatter
  }
  
  public func format(currency: Currency, rate: Decimal) -> String {
    let formattedRate = decimalAmountFormatter.format(amount: rate, maximumFractionDigits: 4)
    return TKLocales.Buy.rate(formattedRate, currency.rawValue)
  }
}
