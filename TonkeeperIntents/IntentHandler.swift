//
//  IntentHandler.swift
//  TonkeeperIntents
//
//  Created by Grigory on 3.10.23..
//

import Intents
import WalletCoreCore
import KeeperCore
import TKCore

class IntentHandler: INExtension, RateWidgetIntentHandling, BalanceWidgetIntentHandling {
  func provideWalletOptionsCollection(for intent: BalanceWidgetIntent) async throws -> INObjectCollection<WidgetWallet> {
    let coreAssembly = TKCore.CoreAssembly()
    let keeperCoreAssembly = KeeperCore.Assembly(
      dependencies: Assembly.Dependencies(
        cacheURL: coreAssembly.cacheURL,
        sharedCacheURL: coreAssembly.sharedCacheURL
      )
    )
    
    let widgetAssembly = keeperCoreAssembly.widgetAssembly()
    let walletsService = widgetAssembly.walletsService
    let wallets = try walletsService.getWallets()
    let widgetWallets = wallets.compactMap {
      let display = $0.metaData.emoji + $0.metaData.label
      return try? WidgetWallet(identifier: $0.identity.identifier().string, display: display)
    }
    let collection = INObjectCollection(items: widgetWallets)
    return collection
  }
  
  func provideCurrencyOptionsCollection(for intent: BalanceWidgetIntent, 
                                        with completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void) {
    let currencies: [WidgetCurrency] = WalletCoreCore.Currency.allCases.map { currency in
      WidgetCurrency(identifier: currency.code, display: currency.code)
    }
    
    let collection = INObjectCollection(items: currencies)
    completion(collection, nil)
  }
  
  func provideCurrencyOptionsCollection(for intent: RateWidgetIntent,
                                        with completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void) {
    
    let currencies: [WidgetCurrency] = WalletCoreCore.Currency.allCases.map { currency in
      WidgetCurrency(identifier: currency.code, display: currency.code)
    }
    
    let collection = INObjectCollection(items: currencies)
    completion(collection, nil)
  }
}
