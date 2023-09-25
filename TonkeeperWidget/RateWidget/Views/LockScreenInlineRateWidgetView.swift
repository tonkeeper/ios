//
//  LockScreenInlineRateWidgetView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI

struct LockScreenInlineRateWidgetView: View {
  let entry: RateWidgetEntry
  var body: some View {
    Text("TON: " + entry.information.amount)
      .font(.system(size: 14, weight: .bold, design: .monospaced))
  }
}

