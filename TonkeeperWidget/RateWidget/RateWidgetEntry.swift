//
//  RateWidgetEntry.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import WidgetKit
import WalletCoreKeeper
import TKChart

struct RateWidgetEntry: TimelineEntry {
  
  struct Information {
    enum DiffDirection {
      case none
      case up
      case down
    }
    
    let date: String
    let amount: String
    let percentDiff: String
    let fiatDiff: String
    let diffDirection: DiffDirection
    
    init(date: String,
         amount: String,
         percentDiff: String,
         fiatDiff: String,
         diffDirection: DiffDirection) {
      self.date = date
      self.amount = amount
      self.percentDiff = percentDiff
      self.fiatDiff = fiatDiff
      self.diffDirection = diffDirection
    }
    
    init(chartPointInformationViewModel: ChartPointInformationViewModel) {
      let diffDirection: Information.DiffDirection
      switch chartPointInformationViewModel.diff.direction {
      case .down: diffDirection = .down
      case .up: diffDirection = .up
      case .none: diffDirection = .none
      }
      self.date = chartPointInformationViewModel.date
      self.amount = chartPointInformationViewModel.amount
      self.percentDiff = chartPointInformationViewModel.diff.percent
      self.fiatDiff = chartPointInformationViewModel.diff.fiat
      self.diffDirection = diffDirection
    }
  }
  
  struct ChartData {
    let data: TKLineChartView.Data
    let minimumValue: String
    let maximumValue: String
  }
  
  let date: Date
  let period: String
  let information: Information
  let chartData: ChartData
}
