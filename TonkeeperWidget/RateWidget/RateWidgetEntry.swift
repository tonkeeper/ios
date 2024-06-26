//
//  RateWidgetEntry.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import WidgetKit
import KeeperCore
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
    
    init(chartPointInformationModel: ChartPointInformationModel) {
      let diffDirection: Information.DiffDirection
      switch chartPointInformationModel.diff.direction {
      case .down: diffDirection = .down
      case .up: diffDirection = .up
      case .none: diffDirection = .none
      }
      self.date = chartPointInformationModel.date
      self.amount = chartPointInformationModel.amount
      self.percentDiff = chartPointInformationModel.diff.percent
      self.fiatDiff = chartPointInformationModel.diff.fiat
      self.diffDirection = diffDirection
    }
  }
  
  struct ChartData {
    let data: TKLineChartView.ChartData
    let minimumValue: String
    let maximumValue: String
  }
  
  let date: Date
  let period: String
  let information: Information
  let chartData: ChartData
}
