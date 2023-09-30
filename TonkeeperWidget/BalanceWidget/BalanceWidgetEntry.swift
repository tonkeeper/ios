//
//  BalanceWidgetEntry.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 26.9.23..
//

import WidgetKit
import WalletCore

struct BalanceWidgetEntry: TimelineEntry {
  let date: Date
  let loadResult: Result<BalanceWidgetController.Model, BalanceWidgetController.Error>
  
  init(date: Date,
       loadResult: Result<BalanceWidgetController.Model, BalanceWidgetController.Error>) {
    self.date = date
    self.loadResult = loadResult
  }
}
