//
//  RateWidgetView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI
import WidgetKit

struct RateWidgetView: View {
  let entry: RateWidgetEntry
  
  @Environment(\.widgetFamily) var family: WidgetFamily
  
  var body: some View {
    switch family {
    case .systemSmall, .systemMedium, .systemLarge:
      HomeScreenRateWidgetView(entry: entry)
    case .accessoryInline:
      LockScreenInlineRateWidgetView(entry: entry)
    case .accessoryRectangular:
      LockScreenRectangleRateWidgetView(entry: entry)
    default:
      Text("MOCK")
    }
  }
}
