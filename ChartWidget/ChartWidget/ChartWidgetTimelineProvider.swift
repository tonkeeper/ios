//
//  ChartWidgetTimelineProvider.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import SwiftUI
import WidgetKit
import WalletCore
import TKChart

struct ChartWidgetTimelineProvider: IntentTimelineProvider {
  
  func placeholder(in context: Context) -> ChartWidgetEntry {
    let entry = ChartWidgetEntry(
      date: Date(),
      period: "W",
      information: .init(date: "2018 Wed, 31 Oct",
                         amount: "$2.3381",
                         percentDiff: "+63.08%",
                         fiatDiff: "$0.90",
                         diffDirection: .up),
      chartData: MockChartData.data
    )
    return entry
  }
  
  func getSnapshot(for configuration: ChartWidgetIntent,
                   in context: Context,
                   completion: @escaping (ChartWidgetEntry) -> Void) {
    let entry = ChartWidgetEntry(
      date: Date(),
      period: "W",
      information: .init(date: "2018 Wed, 31 Oct",
                         amount: "$2.3381",
                         percentDiff: "+63.08%",
                         fiatDiff: "$0.90",
                         diffDirection: .up),
      chartData: MockChartData.data
    )
    completion(entry)
  }

  func getTimeline(for configuration: ChartWidgetIntent, 
                   in context: Context,
                   completion: @escaping (Timeline<ChartWidgetEntry>) -> Void) {
    let cacheURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let chartController = WalletCoreContainer(cacheURL: cacheURL).chartController()
    Task {
      let period: ChartController.Period
      let mode: TKLineChartView.Mode
      switch configuration.period {
      case .day: 
        period = .day
        mode = .linear
      case .halfyear:
        period = .halfYear
        mode = .linear
      case .hour:
        period = .hour
        mode = .stepped
      case .month: 
        period = .month
        mode = .linear
      case .unknown:
        period = .week
        mode = .linear
      case .week:
        period = .week
        mode = .linear
      case .year:
        period = .year
        mode = .linear
      }
      let data = try await chartController.getChartData(period: period)
      let information = await chartController.getInformation(at: data.count-1, period: period)
      let entryInformation = ChartWidgetEntry.Information(chartPointInformationViewModel: information)
      let entry = ChartWidgetEntry(date: Date(),
                                   period: period.title,
                                   information: entryInformation,
                                   chartData: .init(coordinates: data, mode: mode))
      let nextUpdate = Calendar.current.date(byAdding: DateComponents(minute: 30), to: Date())!
      let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
      completion(timeline)
    }
  }
}

extension WalletCore.Coordinate: TKChart.Coordinate {}
