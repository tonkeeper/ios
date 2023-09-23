//
//  ChartWidgetEntry.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import SwiftUI
import WidgetKit
import WalletCore
import TKChart

struct ChartWidgetEntry: TimelineEntry {
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
  
  let date: Date
  let period: String
  let information: Information
  let chartData: TKLineChartView.Data
}
