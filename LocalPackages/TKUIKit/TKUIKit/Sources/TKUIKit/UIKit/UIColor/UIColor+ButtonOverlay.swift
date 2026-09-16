import UIKit

/// Overlay-button aliases predating the generated palette; they map onto
/// constant palette entries and intentionally live outside codegen.
public extension UIColor.Button {
    static let overlayBackground = UIColor {
        TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantWhite
    }

    static let overlayForeground = UIColor {
        TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantBlack
    }

    static let overlayBackgroundDisabled = UIColor {
        TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantWhite
    }

    static let overlayBackgroundHighlighted = UIColor {
        TKThemeManager.shared.themeAppearance.colorScheme(for: $0.userInterfaceStyle).constantWhite
    }
}
