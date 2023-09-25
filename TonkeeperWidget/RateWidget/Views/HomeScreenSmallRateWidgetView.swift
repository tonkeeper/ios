//
//  HomeScreenSmallRateWidgetView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 26.9.23..
//

import SwiftUI
import WidgetKit

struct HomeScreenSmallRateWidgetView: View {
  let entry: RateWidgetEntry
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("TON")
        .foregroundColor(Color(UIColor.Text.secondary))
        .font(.system(size: 13, weight: .medium))
      Spacer()
      RateWidgetDataView(information: entry.information, isRegularOrder: false)
        .padding(.bottom, 10)
      HStack {
        Text("Updated at ") + Text(entry.date, style: .time)
      }
      .opacity(0.56)
      .foregroundColor(Color(UIColor.Text.tertiary))
      .font(.system(size: 13, weight: .regular))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    .widgetBackground(backgroundView: Color(UIColor.Background.page))
  }
}
