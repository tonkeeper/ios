//
//  LockScreenRectangleChartWidgetVie.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import SwiftUI

struct LockScreenRectangleChartWidgetView: View {
  let entry: ChartWidgetEntry
  var body: some View {
    VStack(alignment: .leading) {
      Text(entry.information.date)
      ChartWidgetAmountView(information: entry.information)
    }
  }
}
