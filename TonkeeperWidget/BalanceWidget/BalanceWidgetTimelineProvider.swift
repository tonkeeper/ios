//
//  BalanceWidgetTimelineProvider.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 26.9.23..
//

import WidgetKit
import TKCore
import WalletCore

struct BalanceWidgetTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> BalanceWidgetEntry {
    mockEntry()
  }
  
  func getSnapshot(in context: Context,
                   completion: @escaping (BalanceWidgetEntry) -> Void) {
    completion(mockEntry())
  }
  
  func getTimeline(in context: Context,
                   completion: @escaping (Timeline<BalanceWidgetEntry>) -> Void) {
    let coreAssembly = CoreAssembly()
    let walletCoreContainer = WalletCoreContainer(dependencies: Dependencies(
      cacheURL: coreAssembly.cacheURL,
      sharedCacheURL: coreAssembly.sharedCacheURL,
      sharedKeychainGroup: coreAssembly.keychainAccessGroupIdentifier)
    )
    let balanceWidgetController = walletCoreContainer.balanceWidgetController()
    Task {
      let entry: BalanceWidgetEntry
      do {
        let model = try await balanceWidgetController.loadBalance()
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
