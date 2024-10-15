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
    let amountNumber = NSDecimalNumber(decimal: amount)
    let amountFractionalLength = max(Int16(-amount.exponent), 0)
    let amountFractional = amountNumber
      .subtracting(NSDecimalNumber(integerLiteral: amountNumber.intValue))
      .multiplying(byPowerOf10: amountFractionalLength)
    let notZeroFractionalCount = String(amountFractional.intValue).count
    let formatterFractinalDigitsCount = Int(amountFractionalLength) - notZeroFractionalCount + min(maximumNotZeroFractionalCount, notZeroFractionalCount)
    return formatterFractinalDigitsCount
  }
}
