//
//  HomeScreenSmallRateChartWidgetView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI
import WidgetKit

struct HomeScreenSmallRateChartWidgetView: View {
  let entry: RateWidgetEntry
  var body: some View {
    ZStack {
      RateWidgetChartView(chartData: entry.chartData)
        .padding(EdgeInsets(top: 24, leading: 0, bottom: 62, trailing: 0))
      VStack(alignment: .leading) {
        Text("TON")
          .foregroundColor(Color(UIColor.Text.secondary))
          .font(.system(size: 13, weight: .medium))
        Spacer()
        RateWidgetDataView(information: entry.information)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }
    .widgetBackground(backgroundView: Color(UIColor.Background.page))
  }
}

