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
    case .systemSmall:
      HomeScreenSmallRateChartWidgetView(entry: entry)
    case .systemMedium:
      HomeScreenMediumRateChartWidgetView(entry: entry)
    default:
      Text("MOCK")
    }
  }
}
