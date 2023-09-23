//
//  HomeScreenChartWidgetView.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import SwiftUI
import WidgetKit

struct HomeScreenChartWidgetView: View {
  let entry: ChartWidgetEntry
  var body: some View {
    VStack(alignment: .leading) {
      VStack(alignment: .leading) {
        HStack(alignment: .top) {
          ChartWidgetAmountView(information: entry.information)
          if #available(iOSApplicationExtension 17.0, *) {
            Spacer()
            ChartWidgetReloadButtonView()
          }
        }
        Text(entry.period)
          .font(.system(size: 12, design: .monospaced))
          .foregroundColor(Color(UIColor.Text.secondary))
      }
      .padding(EdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 10))
      ChartWidgetChartView(
        chartData: entry.chartData
      )
      Spacer()
    }
    .widgetBackground(backgroundView: Color(UIColor.Background.page))
  }
}
