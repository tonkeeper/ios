//
//  RateWidgetTimelineProvider.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import WidgetKit
import KeeperCore
import TKCore
import TKChart

struct RateWidgetTimelineProvider: IntentTimelineProvider {
  func placeholder(in context: Context) -> RateWidgetEntry {
    RateWidgetEntry(
      date: Date(),
      period: "W",
      information: .init(date: "2018 Wed, 31 Oct",
                         amount: "$2.3381",
                         percentDiff: "+63.08%",
                         fiatDiff: "$0.90",
                         diffDirection: .up),
      chartData: .init(data: RateWidgetChartMock.data,
                       minimumValue: "$1.47",
                       maximumValue: "$2.57")
    )
  }
  
  func getSnapshot(for configuration: RateWidgetIntent,
                   in context: Context,
                   completion: @escaping (RateWidgetEntry) -> Void) {
    let entry = RateWidgetEntry(
      date: Date(),
      period: "W",
      information: .init(date: "2018 Wed, 31 Oct",
                         amount: "$2.3381",
                         percentDiff: "+63.08%",
                         fiatDiff: "$0.90",
                         diffDirection: .up),
      chartData: .init(data: RateWidgetChartMock.data,
                       minimumValue: "$1.47",
                       maximumValue: "$2.57")
    )
    completion(entry)
  }
  
  func getTimeline(
    for configuration: RateWidgetIntent,
    in context: Context,
    completion: @escaping (Timeline<RateWidgetEntry>) -> Void) {
      let currency: Currency
      if let configurationCurrencyIdentifier = configuration.currency?.identifier,
         let configurationCurrency = Currency(rawValue: configurationCurrencyIdentifier) {
        currency = configurationCurrency
      } else {
        currency = .USD
      }
      let coreAssembly = CoreAssembly()
      let keeperCoreAssembly = KeeperCore.Assembly(
        dependencies: Assembly.Dependencies(
          cacheURL: coreAssembly.cacheURL,
          sharedCacheURL: coreAssembly.sharedCacheURL,
          appInfoProvider: coreAssembly.appInfoProvider,
          seedProvider: { "" }
        )
      )
      let chartFormatter = coreAssembly.formattersAssembly.chartFormatter(
        dateFormatter: keeperCoreAssembly.rootAssembly().formattersAssembly.dateFormatter,
        decimalAmountFormatter: keeperCoreAssembly.rootAssembly().formattersAssembly.decimalAmountFormatter
      )
      let chartController = keeperCoreAssembly.widgetAssembly().chartV2Controller(token: .ton)
      
      let period = KeeperCore.Period(period: configuration.period)
      let mode: TKLineChartView.ChartMode
      switch period {
      case .hour: mode = .stepped
      default: mode = .linear
      }
      
      Task {
        let chartData = try await chartController.loadChartData(period: period, currency: currency)
        guard let coordinate = chartData.last else { return }
        let pointInformation = preparePointInformation(
          coordinate: coordinate,
          coordinates: chartData,
          currency: currency,
          chartController: chartController,
          chartFormatter: chartFormatter
        )
        let values = chartData.map { $0.y }
        let maximumValue = chartFormatter.mapMaxMinValue(value: values.max() ?? 0, currency: currency)
        let minimumValue = chartFormatter.mapMaxMinValue(value: values.min() ?? 0, currency: currency)
        let entryInformation = RateWidgetEntry.Information(chartPointInformationModel: pointInformation)
        let entry = RateWidgetEntry(
          date: Date(),
          period: period.title,
          information: entryInformation,
          chartData: .init(
            data: TKLineChartView.ChartData(
              mode: mode,
              coordinates: chartData
            ),
            minimumValue: minimumValue,
            maximumValue: maximumValue
          )
        )
        let nextUpdate = Calendar.current.date(byAdding: DateComponents(minute: 30), to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
      }
    }
}

private extension RateWidgetTimelineProvider {
  func preparePointInformation(coordinate: KeeperCore.Coordinate,
                               coordinates: [KeeperCore.Coordinate],
                               currency: Currency,
                               chartController: ChartV2Controller,
                               chartFormatter: ChartFormatter) -> ChartPointInformationModel {
    let calculatedDiff = chartController.calculateDiff(coordinates: coordinates, coordinate: coordinate)
    
    let price = chartFormatter.formatValue(coordinate: coordinate, currency: currency)
    let formattedDiff = chartFormatter.formatDiff(diff: calculatedDiff.diff)
    let formattedCurrencyDiff = chartFormatter.formatCurrencyDiff(diff: calculatedDiff.currencyDiff, currency: currency)
    
    let direction: ChartPointInformationModel.Diff.Direction
    switch calculatedDiff.diff {
    case let x where x < 0:
      direction = .down
    case let x where x > 0:
      direction = .up
    default:
      direction = .none
    }
    
    let diff = ChartPointInformationModel.Diff(
      percent: formattedDiff,
      fiat: formattedCurrencyDiff,
      direction: direction
    )
    
    return ChartPointInformationModel(
      amount: price,
      diff: diff,
      date: ""
    )
  }
}

private extension KeeperCore.Period {
  init(period: TonkeeperWidgetExtension.Period) {
    switch period {
    case .day:
      self = .day
    case .halfYear:
      self = .halfYear
    case .hour:
      self = .hour
    case .month:
      self = .month
    case .unknown:
      self = .week
    case .week:
      self = .week
    case .year:
      self = .year
    }
  }
}

extension KeeperCore.Coordinate: TKChart.Coordinate {}
