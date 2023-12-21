//
//  BalanceWidgetTimelineProvider.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 26.9.23..
//

import WidgetKit
import TKCore
import WalletCoreKeeper
import WalletCoreCore

struct BalanceWidgetTimelineProvider: IntentTimelineProvider {
  func placeholder(in context: Context) -> BalanceWidgetEntry {
    mockEntry()
  }
  
  func getSnapshot(for configuration: BalanceWidgetIntent,
                   in context: Context,
                   completion: @escaping (BalanceWidgetEntry) -> Void) {
    completion(mockEntry())
  }
  
  func getTimeline(for configuration: BalanceWidgetIntent,
                   in context: Context,
                   completion: @escaping (Timeline<BalanceWidgetEntry>) -> Void) {
    let coreAssembly = CoreAssembly()
    let walletCoreContainer = WalletCoreKeeper.Assembly(dependencies: Dependencies(
      cacheURL: coreAssembly.cacheURL,
      sharedCacheURL: coreAssembly.sharedCacheURL,
      sharedKeychainGroup: coreAssembly.keychainAccessGroupIdentifier)
    )
    let balanceWidgetController = walletCoreContainer.balanceWidgetController()
    let currency: Currency
    if let configurationCurrencyIdentifier = configuration.currency?.identifier,
       let configurationCurrency = Currency(rawValue: configurationCurrencyIdentifier) {
      currency = configurationCurrency
    } else {
      currency = .USD
    }
    Task {
      let entry: BalanceWidgetEntry
      do {
        let model = try await balanceWidgetController.loadBalance(currency: currency)
        entry = BalanceWidgetEntry(date: Date(),
                                   loadResult: .success(model))
      } catch let error as BalanceWidgetController.Error {
        entry = BalanceWidgetEntry(date: Date(),
                                   loadResult: .failure(error))
      }
      let nextUpdate = Calendar.current.date(byAdding: DateComponents(minute: 30), to: Date())!
      let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
      completion(timeline)
    }
  }
  
  private func mockEntry() -> BalanceWidgetEntry {
    let model = BalanceWidgetController.Model(
      tonBalance: "0",
      fiatBalance: "$0",
      address: "EQDY...naPP"
    )
    return BalanceWidgetEntry(date: Date(),
                              loadResult: .success(model))
  }
}
