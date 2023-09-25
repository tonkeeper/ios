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
  
  @Environment(\.widgetFamily) var family: WidgetFamily
  var amountFont: Font {
    switch family {
    case .systemSmall:
      return .system(size: 15, weight: .bold, design: .monospaced)
    case .systemMedium:
      return .system(size: 16, weight: .bold, design: .monospaced)
    case .accessoryRectangular, .systemLarge:
      return .system(size: 18, weight: .bold, design: .monospaced)
    default:
      return .system(size: 0, weight: .bold, design: .monospaced)
    }
  }
  var diffFont: Font {
    switch family {
    case .systemSmall:
      return .system(size: 11, weight: .bold, design: .monospaced)
    case .systemMedium:
      return .system(size: 12, weight: .bold, design: .monospaced)
    case .accessoryRectangular, .systemLarge:
      return .system(size: 14, weight: .bold, design: .monospaced)
    default:
      return .system(size: 0, weight: .bold, design: .monospaced)
    }
  }
  var amountColor: Color {
    return Color(UIColor.Text.primary)
  }
  var diffPercentColor: Color {
    switch family {
    case .systemSmall, .systemMedium, .systemLarge:
      let color: UIColor
      switch information.diffDirection {
      case .up: color = .Accent.green
      case .none: color = .Text.secondary
      case .down: color = .Accent.red
      }
      return Color(color)
    case .accessoryRectangular:
      return Color(UIColor.Text.primary)
    default:
      return Color(UIColor.Text.primary)
    }
  }
  var diffFiatColor: Color {
    switch family {
    case .systemSmall, .systemMedium, .systemLarge:
      let color: UIColor
      switch information.diffDirection {
      case .up: color = .Accent.green
      case .none: color = .Text.secondary
      case .down: color = .Accent.red
      }
      return Color(color).opacity(0.44)
    case .accessoryRectangular:
      return Color(UIColor.Text.primary)
    default:
      return Color(UIColor.Text.primary)
    }
  }
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(information.amount)
        .foregroundColor(amountColor)
        .font(amountFont)
      HStack {
        Text(information.percentDiff)
          .foregroundColor(diffPercentColor)
          .font(diffFont)
        Text(information.fiatDiff)
          .foregroundColor(diffFiatColor)
          .font(diffFont)
      }
    }
  }
}
