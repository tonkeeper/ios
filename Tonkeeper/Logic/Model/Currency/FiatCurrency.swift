//
//  FiatCurrency.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import Foundation

enum FiatCurrency: Currency {
  case usd
  
  var code: String {
    switch self {
    case .usd: return "USD"
    }
  }
  
  var maximumFractionDigits: Int {
    2
  }
}
