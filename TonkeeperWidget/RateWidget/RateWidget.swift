//
//  RateWidget.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import WidgetKit
import SwiftUI

struct RateWidget: Widget {
  let kind: String = "RateWidget"
  
  var supportedFamilies: [WidgetFamily] {
    var result: [WidgetFamily] = [.systemSmall, .systemMedium]
    if #available(iOSApplicationExtension 16.0, *) {
      result.append(contentsOf: [.accessoryInline, .accessoryRectangular])
    }
    if #available(iOSApplicationExtension 17.0, *) {
      result.append(.systemLarge)
    }
    return result
  }
  
  var body: some WidgetConfiguration {
    IntentConfiguration(
      kind: kind,
      intent: RateWidgetIntent.self,
      provider: RateWidgetTimelineProvider()) { entry in
        RateWidgetView(entry: entry)
      }
      .configurationDisplayName("Rate")
      .description("")
      .supportedFamilies(supportedFamilies)
      .contentMarginsDisabledIfAvailable()
  }
}


