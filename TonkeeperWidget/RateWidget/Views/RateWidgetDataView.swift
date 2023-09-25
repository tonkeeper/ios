//
//  RateWidgetDataView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI
import WidgetKit

struct RateWidgetDataView: View {
  let information: RateWidgetEntry.Information
  let isRegularOrder: Bool
  
  var amountColor: Color {
    return Color(UIColor.Text.primary)
  }
  var diffPercentColor: Color {
    let color: UIColor
    switch information.diffDirection {
    case .up: color = .Accent.green
    case .none: color = .Text.secondary
    case .down: color = .Accent.red
    }
    return Color(color)
  }
  var diffFiatColor: Color {
    let color: UIColor
    switch information.diffDirection {
    case .up: color = .Accent.green
    case .none: color = .Text.secondary
    case .down: color = .Accent.red
    }
    return Color(color).opacity(0.44)
  }
  
  var amountView: some View {
    Text(information.amount)
      .foregroundColor(amountColor)
      .font(.system(size: 28, weight: .medium))
  }
  
  var diffView: some View {
    HStack {
      Text(information.percentDiff)
        .foregroundColor(diffPercentColor)
        .font(.system(size: 13, weight: .medium))
      Text(information.fiatDiff)
        .foregroundColor(diffFiatColor)
        .font(.system(size: 13, weight: .medium))
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if isRegularOrder {
        amountView
        diffView
      } else {
        diffView
        amountView
      }
    }
  }
}
