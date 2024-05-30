import Foundation
import BigInt

public struct AmountNewFormatter {
  
  private let groupingSeparator = FormattersConstants.groupingSeparator
  private let fractionalSeparator = FormattersConstants.fractionalSeparator
  
  private let bigIntFormatter: BigIntAmountFormatter
  
  init(bigIntFormatter: BigIntAmountFormatter) {
    self.bigIntFormatter = bigIntFormatter
  }
  
  public func formatAmount(_ amount: BigUInt,
                           fractionDigits: Int,
                           maximumFractionDigits: Int,
                           currency: Currency? = nil) -> String {
    var formatted = bigIntFormatter.format(
      amount: amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: maximumFractionDigits,
      groupingSeparator: groupingSeparator,
      fractionalSeparator: fractionalSeparator
    )
    if let currency = currency {
      let format: String
      if currency.symbolOnLeft {
        format = "\(currency.symbol)\(String.Symbol.shortSpace)%@"
      } else {
        format = "%@\(String.Symbol.shortSpace)\(currency.symbol)"
      }
      formatted = String(format: format, formatted)
    }
    return formatted
  }
  
  public func amount(from stringAmount: String,
                     targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    do {
      return try bigIntFormatter.bigUInt(
        string: stringAmount,
        targetFractionalDigits: targetFractionalDigits,
        fractionalSeparator: fractionalSeparator
      )
    } catch {
      return (0, targetFractionalDigits)
    }
  }
}
