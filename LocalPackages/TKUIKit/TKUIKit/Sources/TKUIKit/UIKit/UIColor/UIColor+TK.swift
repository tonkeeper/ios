import UIKit

public extension UIColor {
  enum Background {
    public static let contentAttention = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).backgroundContentAttention
    }
    public static let contentTint = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).backgroundContentTint
    }
    public static let content = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).backgroundContent
    }
    public static let highlighted = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).backgroundHighlighted
    }
    public static let overlayExtraLight = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).backgroundOverlayExtraLight
    }
    public static let overlayLight = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).backgroundOverlayLight
    }
    public static let overlayStrong = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).backgroundOverlayStrong
    }
    public static let page = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).backgroundPage
    }
    public static let transparent = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).backgroundTransparent
    }
  }
  enum Button {
    public static let primaryBackgroundDisabled = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonPrimaryBackgroundDisabled
    }
    public static let primaryBackgroundHighlighted = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonPrimaryBackgroundHighlighted
    }
    public static let primaryBackground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonPrimaryBackground
    }
    public static let overlayBackground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantWhite
    }
    public static let overlayForeground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantBlack
    }
    public static let overlayBackgroundDisabled = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantWhite
    }
    public static let overlayBackgroundHighlighted = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantWhite
    }
    public static let primaryForeground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonPrimaryForeground
    }
    public static let secondaryBackgroundDisabled = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonSecondaryBackgroundDisabled
    }
    public static let secondaryBackgroundHighlighted = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonSecondaryBackgroundHighlighted
    }
    public static let secondaryBackground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonSecondaryBackground
    }
    public static let secondaryForeground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonSecondaryForeground
    }
    public static let tertiaryBackgroundDisabled = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonTertiaryBackgroundDisabled
    }
    public static let tertiaryBackgroundHighlighted = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonTertiaryBackgroundHighlighted
    }
    public static let tertiaryBackground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonTertiaryBackground
    }
    public static let tertiaryForeground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).buttonTertiaryForeground
    }
  }
  enum Field {
    public static let activeBorder = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).fieldActiveBorder
    }
    public static let background = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).fieldBackground
    }
    public static let errorBackground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).fieldErrorBackground
    }
    public static let errorBorder = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).fieldErrorBorder
    }
  }
  enum Icon {
    public static let primaryAlternate = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).iconPrimaryAlternate
    }
    public static let primary = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).iconPrimary
    }
    public static let secondary = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).iconSecondary
    }
    public static let tertiary = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).iconTertiary
    }
  }
  enum Separator {
    public static let alternate = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).separatorAlternate
    }
    public static let common = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).separatorCommon
    }
  }
  enum TabBar {
    public static let activeIcon = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).tabBarActiveIcon
    }
    public static let inactiveIcon = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).tabBarInactiveIcon
    }
  }
  enum Text {
    public static let accent = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).textAccent
    }
    public static let primaryAlternate = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).textPrimaryAlternate
    }
    public static let primary = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).textPrimary
    }
    public static let secondary = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).textSecondary
    }
    public static let tertiary = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).textTertiary
    }
  }
  enum Bubble {
    public static let background = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).bubbleBackground
    }
    public static let foreground = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).bubbleForeground
    }
  }
  enum Accent {
    public static let blue = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).accentBlue
    }
    public static let green = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).accentGreen
    }
    public static let red = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).accentRed
    }
    public static let orange = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).accentOrange
    }
    public static let purple = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).accentPurple
    }
  }
  enum Constant {
    public static let tonBlue = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantTonBlue
    }
    
    public static let white = UIColor {
      TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantWhite
    }
  }
  
  static func named(_ name: String) -> UIColor {
    let color = UIColor(named: name, in: .module, compatibleWith: nil)
    assert(color != nil, "Can't load color with name: \(name)")
    return color ?? .black
  }
}
