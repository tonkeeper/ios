//
//  LockScreenRectangleRateWidgetView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI

struct LockScreenRectangleRateWidgetView: View {
  let entry: RateWidgetEntry
  var body: some View {
    VStack(alignment: .leading) {
      Text(entry.date, style: .time)
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(Color(UIColor.Text.secondary))
      HStack(alignment: .top) {
        RateWidgetDataView(information: entry.information)
        if #available(iOSApplicationExtension 17.0, *) {
          Spacer()
          RateWidgetReloadButtonView()
        }
      }
    }
  }
}

