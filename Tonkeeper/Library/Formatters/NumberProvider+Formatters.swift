//
//  CurrencyNumberFormatter.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import Foundation

extension NumberFormatter {
  static var currencyFormatter: NumberFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = " "
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumFractionDigits = 9
    numberFormatter.maximumIntegerDigits = 20
    return numberFormatter
  }
}
