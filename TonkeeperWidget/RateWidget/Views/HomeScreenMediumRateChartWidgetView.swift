//
//  HomeScreenMediumRateChartWidgetView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI
import WidgetKit

struct HomeScreenMediumRateChartWidgetView: View {
  let entry: RateWidgetEntry
  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 0) {
        Text("TON")
          .foregroundColor(Color(UIColor.Text.secondary))
          .font(.system(size: 13, weight: .medium))
          .padding(.bottom, 8)
        RateWidgetDataView(information: entry.information)
        Spacer()
      }
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 26))
      Color(.Background.highlighted)
        .frame(width: 0.5)
      ZStack(alignment: .trailing) {
        RateWidgetChartView(chartData: entry.chartData)
          .background(Color.green)
          .padding(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
        VStack(alignment: .trailing) {
          Text(entry.chartData.maximumValue)
            .foregroundColor(Color(UIColor.Text.tertiary))
            .font(.system(size: 11, weight: .regular))
          Spacer()
          Text(entry.chartData.minimumValue)
            .foregroundColor(Color(UIColor.Text.tertiary))
            .font(.system(size: 11, weight: .regular))
        }
        .padding(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 16))
      }
    }
  }
}
