//
//  IntentHandler.swift
//  TonkeeperIntents
//
//  Created by Grigory on 3.10.23..
//

import Intents
import WalletCore

class IntentHandler: INExtension, RateWidgetIntentHandling, BalanceWidgetIntentHandling {
  func provideCurrencyOptionsCollection(for intent: BalanceWidgetIntent, 
                                        with completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void) {
    let currencies: [WidgetCurrency] = WalletCore.Currency.allCases.map { currency in
      WidgetCurrency(identifier: currency.code, display: currency.code)
    }
    
    let collection = INObjectCollection(items: currencies)
    completion(collection, nil)
  }
  
  func provideCurrencyOptionsCollection(for intent: RateWidgetIntent,
                                        with completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void) {
    
    let currencies: [WidgetCurrency] = WalletCore.Currency.allCases.map { currency in
      WidgetCurrency(identifier: currency.code, display: currency.code)
    }
    
    let collection = INObjectCollection(items: currencies)
    completion(collection, nil)
  }
}

//class IntentHandler: INExtension, RateWidgetIntentHandling {
//  func provideCurrencyOptionsCollection(for intent: RateWidgetIntent,
//                                        with completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void) {
//    
//    let currencies: [WidgetCurrency] = WalletCore.Currency.allCases.map { currency in
//      WidgetCurrency(identifier: currency.code, display: currency.code)
//    }
//    
//    let collection = INObjectCollection(items: currencies)
//    completion(collection, nil)
//  }
//}
