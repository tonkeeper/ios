//
//  CryptoCurrency.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import Foundation

enum CryptoCurrency: Currency {
  case ton
  
  var code: String {
    switch self {
    case .ton: return "TON"
    }
  }
  
  var maximumFractionDigits: Int {
    9
  }
}
