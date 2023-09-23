//
//  ChartWidget.swift
//  ChartWidget
//
//  Created by Grigory on 22.9.23..
//

import WidgetKit
import SwiftUI

struct ChartWidget: Widget {
  let kind: String = "ChartWidget"
  
  var supportedFamilies: [WidgetFamily] {
    var result: [WidgetFamily] = [.systemSmall, .systemMedium]
    if #available(iOSApplicationExtension 16.0, *) {
      result.append(contentsOf: [.accessoryInline, .accessoryRectangular])
    }
    return result
  }
  
  var body: some WidgetConfiguration {
    IntentConfiguration(
      kind: kind,
      intent: ChartWidgetIntent.self,
      provider: ChartWidgetTimelineProvider()) { entry in
        ChartWidgetView(entry: entry)
      }
      .configurationDisplayName("Chart Widget")
      .description("")
      .supportedFamilies(supportedFamilies)
      .contentMarginsDisabledIfAvailable()
  }
}

