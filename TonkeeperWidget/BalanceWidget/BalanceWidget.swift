//
//  BalanceWidget.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 26.9.23..
//

import WidgetKit
import SwiftUI

struct BalanceWidget: Widget {
  let kind = "BalanceWidget"
  
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: BalanceWidgetTimelineProvider()) { entry in
        BalanceWidgetView(entry: entry)
          .widgetBackground(backgroundView: Color(UIColor.Background.page))
      }
      .configurationDisplayName("Wallet balance")
      .description("")
      .supportedFamilies([.systemSmall, .systemMedium])
      .contentMarginsDisabledIfAvailable()
  }
}
