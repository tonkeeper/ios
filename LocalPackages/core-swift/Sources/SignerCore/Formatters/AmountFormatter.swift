import Foundation
import BigInt

public struct AmountFormatter {
  private let bigIntFormatter: BigIntAmountFormatter
  
  init(bigIntFormatter: BigIntAmountFormatter) {
    self.bigIntFormatter = bigIntFormatter
  }
  
  public func formatAmount(_ amount: BigUInt,
                           fractionDigits: Int,
                           maximumFractionDigits: Int) -> String {
    return bigIntFormatter.format(
      amount: amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: maximumFractionDigits)
  }
  
  public func formatAmountWithoutFractionIfThousand(_ amount: BigUInt,
                                                    fractionDigits: Int,
                                                    maximumFractionDigits: Int) -> String {
    let isMoreThanThousand = isMoreThanThousand(amount: amount, fractionalDigits: fractionDigits)
    let maximumFractionDigits = isMoreThanThousand ? 0 : maximumFractionDigits
    return formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: maximumFractionDigits
    )
  }
  
  public func formatAmount(_ amount: BigUInt,
                           fractionDigits: Int,
                           maximumFractionDigits: Int,
                           symbol: String?) -> String {
    var formatted = bigIntFormatter.format(
      amount: amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: maximumFractionDigits)
    if let symbol = symbol {
      formatted = formatted + .Symbol.shortSpace + symbol
    }
    return formatted
  }
}


private extension AmountFormatter {
  func isMoreThanThousand(amount: BigUInt, fractionalDigits: Int) -> Bool {
    let amountString = amount.description
    let fullAmountString: String
    if amountString.count < fractionalDigits {
      fullAmountString = String(repeating: "0", count: fractionalDigits - amountString.count) + amountString
    } else {
      fullAmountString = amountString
    }
    let integerLength = fullAmountString.count - fractionalDigits
    return integerLength >= 4
  }
}

extension String {
  enum Symbol {
    static let minus = "\u{2212}"
    static let plus = "\u{002B}"
    static let shortSpace = "\u{2009}"
    static let almostEqual = "\u{2248}"
    static let middleDot = "\u{00B7}"
  }
}
