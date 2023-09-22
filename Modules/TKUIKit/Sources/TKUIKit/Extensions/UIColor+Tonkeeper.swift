//
//  UIColor+Tonkeeper.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

public extension UIColor {
  enum Background {
    public static let contentAttention = UIColor.named("Colors/Background/Content Attention")
    public static let contentTint = UIColor.named("Colors/Background/Content Tint")
    public static let content = UIColor.named("Colors/Background/Content")
    public static let highlighted = UIColor.named("Colors/Background/Highlighted")
    public static let overlayExtraLight = UIColor.named("Colors/Background/Overlay Extra Light")
    public static let overlayLight = UIColor.named("Colors/Background/Overlay Light")
    public static let overlayStrong = UIColor.named("Colors/Background/Overlay Strong")
    public static let page = UIColor.named("Colors/Background/Page")
    public static let transparent = UIColor.named("Colors/Background/Transparent")
  }
  enum Button {
    public static let primaryBackgroundDisabled = UIColor.named("Colors/Button/Primary Background Disabled")
    public static let primaryBackgroundHighlighted = UIColor.named("Colors/Button/Primary Background Highlighted")
    public static let primaryBackground = UIColor.named("Colors/Button/Primary Background")
    public static let primaryForeground = UIColor.named("Colors/Button/Primary Foreground")
    public static let secondaryBackgroundDisabled = UIColor.named("Colors/Button/Secondary Background Disabled")
    public static let secondaryBackgroundHighlighted = UIColor.named("Colors/Button/Secondary Background Highlighted")
    public static let secondaryBackground = UIColor.named("Colors/Button/Secondary Background")
    public static let secondaryForeground = UIColor.named("Colors/Button/Secondary Foreground")
    public static let tertiaryBackgroundDisabled = UIColor.named("Colors/Button/Tertiary Background Disabled")
    public static let tertiaryBackgroundHighlighted = UIColor.named("Colors/Button/Tertiary Background Highlighted")
    public static let tertiaryBackground = UIColor.named("Colors/Button/Tertiary Background")
    public static let tertiaryForeground = UIColor.named("Colors/Button/Tertiary Foreground")
  }
  enum Field {
    public static let activeBorder = UIColor.named("Colors/Field/Active Border")
    public static let background = UIColor.named("Colors/Field/Background")
    public static let errorBackground = UIColor.named("Colors/Field/Error Background")
    public static let errorBorder = UIColor.named("Colors/Field/Error Border")
  }
  enum Icon {
    public static let primaryAlternate = UIColor.named("Colors/Icon/Primary Alternate")
    public static let primary = UIColor.named("Colors/Icon/Primary")
    public static let secondary = UIColor.named("Colors/Icon/Secondary")
    public static let tertiary = UIColor.named("Colors/Icon/Tertiary")
  }
  enum Separator {
    public static let alternate = UIColor.named("Colors/Separator/Alternate")
    public static let common = UIColor.named("Colors/Separator/Common")
  }
  enum TabBar {
    public static let activeIcon = UIColor.named("Colors/TabBar/Active Icon")
    public static let inactiveIcon = UIColor.named("Colors/TabBar/Inactive Icon")
  }
  enum Text {
    public static let accent = UIColor.named("Colors/Text/Accent")
    public static let primaryAlternate = UIColor.named("Colors/Text/Primary Alternate")
    public static let primary = UIColor.named("Colors/Text/Primary")
    public static let secondary = UIColor.named("Colors/Text/Secondary")
    public static let tertiary = UIColor.named("Colors/Text/Tertiary")
  }
  enum Accent {
    public static let blue = UIColor.named("Colors/Accent/Blue")
    public static let green = UIColor.named("Colors/Accent/Green")
    public static let red = UIColor.named("Colors/Accent/Red")
    public static let orange = UIColor.named("Colors/Accent/Orange")
  }
  enum Constant {
    public static let tonBlue = UIColor.named("Colors/Constant&System/TON Blue")
  }
  
  private static func named(_ name: String) -> UIColor {
    let color = UIColor(named: name, in: .module, compatibleWith: nil)
    assert(color != nil, "Can't load color with name: \(name)")
    return color ?? .black
  }
}
