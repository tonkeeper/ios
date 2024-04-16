//
//  RateChartWidget.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import WidgetKit
import SwiftUI

struct RateChartWidget: Widget {
  let kind: String = "RateChartWidget"
  
  var supportedFamilies: [WidgetFamily] {
    return [.systemSmall, .systemMedium]
  }
  
  var body: some WidgetConfiguration {
    IntentConfiguration(
      kind: kind,
      intent: RateWidgetIntent.self,
      provider: RateWidgetTimelineProvider()) { entry in
        RateChartWidgetView(entry: entry)
          .widgetBackground(backgroundView: Color(UIColor.Background.page))
      }
      .configurationDisplayName("Rate with chart")
      .description("")
      .supportedFamilies(supportedFamilies)
      .contentMarginsDisabledIfAvailable()
  }
}
