//
//  UIColor+Tonkeeper.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

extension UIColor {
  enum Background {
    static let contentAttention = UIColor.named("Colors/Background/Content Attention")
    static let contentTint = UIColor.named("Colors/Background/Content Tint")
    static let content = UIColor.named("Colors/Background/Content")
    static let highlighted = UIColor.named("Colors/Background/Highlighted")
    static let overlayExtraLight = UIColor.named("Colors/Background/Overlay Extra Light")
    static let overlayLight = UIColor.named("Colors/Background/Overlay Light")
    static let overlayStrong = UIColor.named("Colors/Background/Overlay Strong")
    static let page = UIColor.named("Colors/Background/Page")
    static let transparent = UIColor.named("Colors/Background/Transparent")
  }
  enum Button {
    static let primaryBackgroundDisabled = UIColor.named("Colors/Button/Primary Background Disabled")
    static let primaryBackgroundHighlighted = UIColor.named("Colors/Button/Primary Background Highlighted")
    static let primaryBackground = UIColor.named("Colors/Button/Primary Background")
    static let primaryForeground = UIColor.named("Colors/Button/Primary Foreground")
    static let secondaryBackgroundDisabled = UIColor.named("Colors/Button/Secondary Background Disabled")
    static let secondaryBackgroundHighlighted = UIColor.named("Colors/Button/Secondary Background Highlighted")
    static let secondaryBackground = UIColor.named("Colors/Button/Secondary Background")
    static let secondaryForeground = UIColor.named("Colors/Button/Secondary Foreground")
    static let tertiaryBackgroundDisabled = UIColor.named("Colors/Button/Tertiary Background Disabled")
    static let tertiaryBackgroundHighlighted = UIColor.named("Colors/Button/Tertiary Background Highlighted")
    static let tertiaryBackground = UIColor.named("Colors/Button/Tertiary Background")
    static let tertiaryForeground = UIColor.named("Colors/Button/Tertiary Foreground")
  }
  enum Field {
    static let activeBorder = UIColor.named("Colors/Field/Active Border")
    static let background = UIColor.named("Colors/Field/Background")
    static let errorBackground = UIColor.named("Colors/Field/Error Background")
    static let errorBorder = UIColor.named("Colors/Field/Error Border")
  }
  enum Icon {
    static let primaryAlternate = UIColor.named("Colors/Icon/Primary Alternate")
    static let primary = UIColor.named("Colors/Icon/Primary")
    static let secondary = UIColor.named("Colors/Icon/Secondary")
    static let tertiary = UIColor.named("Colors/Icon/Tertiary")
  }
  enum Separator {
    static let alternate = UIColor.named("Colors/Separator/Alternate")
    static let common = UIColor.named("Colors/Separator/Common")
  }
  enum TabBar {
    static let activeIcon = UIColor.named("Colors/TabBar/Active Icon")
    static let inactiveIcon = UIColor.named("Colors/TabBar/Inactive Icon")
  }
  enum Text {
    static let accent = UIColor.named("Colors/Text/Accent")
    static let primaryAlternate = UIColor.named("Colors/Text/Primary Alternate")
    static let primary = UIColor.named("Colors/Text/Primary")
    static let secondary = UIColor.named("Colors/Text/Secondary")
    static let tertiary = UIColor.named("Colors/Text/Tertiary")
  }
  enum Accent {
    static let blue = UIColor.named("Colors/Accent/Blue")
    static let green = UIColor.named("Colors/Accent/Green")
    static let red = UIColor.named("Colors/Accent/Red")
    static let orange = UIColor.named("Colors/Accent/Orange")
  }
  
  private static func named(_ name: String) -> UIColor {
    let color = UIColor(named: name)
    assert(color != nil, "Can't load color with name: \(name)")
    return color ?? .black
  }
}
