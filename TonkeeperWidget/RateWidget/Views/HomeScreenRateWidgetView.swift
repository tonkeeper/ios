//
//  HomeScreenRateWidgetView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI
import WidgetKit

struct HomeScreenRateWidgetView: View {
  let entry: RateWidgetEntry
  var body: some View {
    VStack(alignment: .leading) {
      VStack(alignment: .leading) {
        HStack(alignment: .top) {
          RateWidgetDataView(information: entry.information)
          if #available(iOSApplicationExtension 17.0, *) {
            Spacer()
            RateWidgetReloadButtonView()
          }
        }
        Text(entry.date, style: .time)
          .font(.system(size: 10, design: .monospaced))
          .foregroundColor(Color(UIColor.Text.secondary))
        Text(entry.period)
          .font(.system(size: 12, design: .monospaced))
          .foregroundColor(Color(UIColor.Text.secondary))
      }
      .padding(EdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 10))
      RateWidgetChartView(chartData: entry.chartData)
      Spacer()
    }
    .widgetBackground(backgroundView: Color(UIColor.Background.page))
  }
}
