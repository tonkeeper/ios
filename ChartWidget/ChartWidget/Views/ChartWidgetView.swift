//
//  ChartWidgetView.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import SwiftUI
import WidgetKit

struct ChartWidgetView: View {
  let entry: ChartWidgetEntry
  
  @Environment(\.widgetFamily) var family: WidgetFamily
  
  var body: some View {
    switch family {
    case .accessoryInline:
      LockScreenInlineChartWidgetView(entry: entry)
    case .accessoryRectangular:
      LockScreenRectangleChartWidgetView(entry: entry)
    case .systemMedium, .systemSmall:
      HomeScreenChartWidgetView(entry: entry)
    default:
      HomeScreenChartWidgetView(entry: entry)
    }
  }
}
