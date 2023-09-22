//
//  ChartWidget.swift
//  ChartWidget
//
//  Created by Grigory on 22.9.23..
//

import WidgetKit
import SwiftUI
import TKChart
import WalletCore

struct ChartWidgetEntry: TimelineEntry {
  let date: Date
  let amount: String
  let percentDiff: String
  let fiatDiff: String
  let diffColor: Color
  let chartData: TKLineChartView.Data
}

struct ChartWidgetView: View {
  let entry: ChartWidgetEntry
  
  func chartImage(size: CGSize) -> SwiftUI.Image {
    let chartView = TKLineChartView()
    chartView.frame.size = size
    chartView.layoutIfNeeded()
    chartView.setData(entry.chartData)
    if let image = chartView.getChartImage(transparent: false) {
      return .init(uiImage: image)
    }
    return .init(uiImage: .Images.Mock.mercuryoLogo!)
  }
  
  @Environment(\.widgetFamily) var family: WidgetFamily
  
  var amountFont: Font {
    switch family {
    case .systemSmall:
      return .system(size: 14, weight: .bold, design: .monospaced)
    default:
      return .system(size: 16, weight: .bold, design: .monospaced)
    }
  }
  
  var diffFont: Font {
    switch family {
    case .systemSmall:
      return .system(size: 10, weight: .bold, design: .monospaced)
    default:
      return .system(size: 12, weight: .bold, design: .monospaced)
    }
  }
  
  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        VStack(alignment: .leading) {
          Text(entry.amount)
            .foregroundColor(Color(UIColor.Text.primary))
            .font(amountFont)
          HStack {
            Text(entry.percentDiff)
              .foregroundColor(entry.diffColor)
              .font(diffFont)
            Text(entry.fiatDiff)
              .foregroundColor(entry.diffColor)
              .font(diffFont)
          }
        }
        if #available(iOSApplicationExtension 17.0, *) {
          Spacer()
          ReloadView()
//              .frame(width: 28, height: 28)
        }
      }
      GeometryReader { geometry in
        chartImage(size: .init(width: geometry.size.width + 20, height: geometry.size.height))
          .offset(x: -10)
      }
      Spacer()
    }
    .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
    .widgetBackground(backgroundView: Color(UIColor.Background.page))
  }
}

extension View {
  func widgetBackground(backgroundView: some View) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      return containerBackground(for: .widget) {
        backgroundView
      }
    } else {
      return background(backgroundView)
    }
  }
}

extension WidgetConfiguration {
  func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 17.0, *) {
      return self.contentMarginsDisabled()
    } else {
      return self
    }
  }
}

struct ChartWidgetTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> ChartWidgetEntry {
    ChartWidgetEntry(
      date: Date(),
      amount: "$2.3380",
      percentDiff: "+63.08%",
      fiatDiff: "$0.90",
      diffColor: Color(UIColor.Accent.green),
      chartData: MockChartData.data)
  }
  
  func getSnapshot(in context: Context, completion: @escaping (ChartWidgetEntry) -> Void) {
    let entry = ChartWidgetEntry(
      date: Date(),
      amount: "$2.3380",
      percentDiff: "+63.08%",
      fiatDiff: "$0.90",
      diffColor: Color(UIColor.Accent.green),
      chartData: MockChartData.data)
    completion(entry)
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<ChartWidgetEntry>) -> Void) {
    let cacheURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let chartController = WalletCoreContainer(cacheURL: cacheURL).chartController()
    Task {
      let period: ChartController.Period = .week
      let data = try await chartController.getChartData(period: period)
      let information = await chartController.getInformation(at: data.count-1, period: period)
      let color: UIColor
      switch information.diff.direction {
      case .up: color = .Accent.green
      case .none: color = .Text.secondary
      case .down: color = .Accent.red
      }
      let entry = ChartWidgetEntry(date: Date(),
                                   amount: information.amount,
                                   percentDiff: information.diff.percent,
                                   fiatDiff: information.diff.fiat,
                                   diffColor: Color(color),
                                   chartData: .init(coordinates: data, mode: .linear))
      let nextUpdate = Calendar.current.date(byAdding: DateComponents(minute: 30), to: Date())!
      let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
      completion(timeline)
    }
  }
}

struct ChartWidget: Widget {
  let kind: String = "ChartWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ChartWidgetTimelineProvider()) { entry in
      ChartWidgetView(entry: entry)
    }
    .configurationDisplayName("Chart Widget")
    .description("")
    .supportedFamilies([
      .systemSmall,
      .systemMedium
    ])
    .contentMarginsDisabledIfAvailable()
  }
}

extension WalletCore.Coordinate: TKChart.Coordinate {}

import AppIntents
import Intents
@available(iOSApplicationExtension 16, *)
struct ReloadChartWidgetIntent: AppIntent {
  static var title: LocalizedStringResource = "Reload chart widget"
  
  init() {}
  
  func perform() async throws -> some IntentResult {
    return .result()
  }
}

@available(iOSApplicationExtension 17, *)
struct ReloadView: View {
  var body: some View {
    Button(intent: ReloadChartWidgetIntent()) {
      Image(uiImage: UIImage.Icons.Widget.refresh!)
        .foregroundColor(Color(uiColor: .Accent.blue))
    }
    .buttonStyle(.plain)
  }
}
