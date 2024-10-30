//
//  DecimalAmountFormatter.swift
//  
//
//  Created by Grigory on 2.7.23..
//

import Foundation
import BigInt

public struct DecimalAmountFormatter {
  private let numberFormatter: NumberFormatter
  
  init(numberFormatter: NumberFormatter) {
    self.numberFormatter = numberFormatter
  }
  
  public func format(amount: Decimal,
                     maximumFractionDigits: Int? = nil,
                     significantFractionDigits: Int = 2,
                     currency: Currency? = nil) -> String {
    let formatterMaximumFractionDigits: Int = maximumFractionDigits ?? calculateFractionalDigitsCount(amount: amount, maximumNotZeroFractionalCount: significantFractionDigits)
    let formatFractional: String
    if formatterMaximumFractionDigits == 0 {
      formatFractional = ""
    } else {
      formatFractional = "." + String(repeating: "#", count: formatterMaximumFractionDigits)
    }
    let decimalNumberAmount = NSDecimalNumber(decimal: amount)
    var format = "#,##0\(formatFractional)"
    if let currency = currency {
      numberFormatter.currencySymbol = currency.symbol
      if currency.symbolOnLeft {
        format = "¤\(String.Symbol.shortSpace)\(format)"
      } else {
        format = "\(format)\(String.Symbol.shortSpace)¤"
      }
    }
    
    numberFormatter.positiveFormat = format
    numberFormatter.roundingMode = .down
    return numberFormatter.string(from: decimalNumberAmount) ?? ""
  }
}

private extension DecimalAmountFormatter {
  func calculateFractionalDigitsCount(amount: Decimal,
                                      maximumNotZeroFractionalCount: Int) -> Int {
    let fractionLength = abs(amount.exponent)
    if fractionLength == 0 { return 0 }
    let fractionalNumber = NSDecimalNumber(decimal: amount.fraction).multiplying(byPowerOf10: Int16(fractionLength))
    return (fractionLength - fractionalNumber.stringValue.count) + min(maximumNotZeroFractionalCount, fractionLength)
  }
}

private extension Decimal {
  func rounded(_ roundingMode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
    var result = Decimal()
    var number = self
    NSDecimalRound(&result, &number, 0, roundingMode)
    return result
  }
  var whole: Decimal { rounded(sign == .minus ? .up : .down) }
  var fraction: Decimal { self - whole }
}

