//
//  LockScreenInlineChartWidgetView.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import SwiftUI

struct LockScreenInlineChartWidgetView: View {
  let entry: ChartWidgetEntry
  var body: some View {
    Text("TON: " + entry.information.amount)
      .font(.system(size: 14, weight: .bold, design: .monospaced))
  }
}
