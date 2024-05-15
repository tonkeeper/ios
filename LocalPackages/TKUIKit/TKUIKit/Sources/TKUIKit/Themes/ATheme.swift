import UIKit

protocol ATheme {
  static var backgroundContentAttention: UIColor { get }
  static var backgroundContentTint: UIColor { get }
  static var backgroundContent: UIColor { get }
  static var backgroundHighlighted: UIColor { get }
  static var backgroundOverlayExtraLight: UIColor { get }
  static var backgroundOverlayLight: UIColor { get }
  static var backgroundOverlayStrong: UIColor { get }
  static var backgroundPage: UIColor { get }
  static var backgroundTransparent: UIColor { get }
  static var backgroundContentPlaceholder: UIColor { get }
  
  static var buttonPrimaryBackgroundDisabled: UIColor { get }
  static var buttonPrimaryBackgroundHighlighted: UIColor { get }
  static var buttonPrimaryBackground: UIColor { get }
  static var buttonPrimaryForeground: UIColor { get }
  static var buttonSecondaryBackgroundDisabled: UIColor { get }
  static var buttonSecondaryBackgroundHighlighted: UIColor { get }
  static var buttonSecondaryBackground: UIColor { get }
  static var buttonSecondaryForeground: UIColor { get }
  static var buttonTertiaryBackgroundDisabled: UIColor { get }
  static var buttonTertiaryBackgroundHighlighted: UIColor { get }
  static var buttonTertiaryBackground: UIColor { get }
  static var buttonTertiaryForeground: UIColor { get }
  
  static var fieldActiveBorder: UIColor { get }
  static var fieldBackground: UIColor { get }
  static var fieldErrorBackground: UIColor { get }
  static var fieldErrorBorder: UIColor { get }
  
  static var iconPrimaryAlternate: UIColor { get }
  static var iconPrimary: UIColor { get }
  static var iconSecondary: UIColor { get }
  static var iconTertiary: UIColor { get }
  
  static var separatorAlternate: UIColor { get }
  static var separatorCommon: UIColor { get }
  
  static var tabBarActiveIcon: UIColor { get }
  static var tabBarInactiveIcon: UIColor { get }
  
  static var textAccent: UIColor { get }
  static var textPrimaryAlternate: UIColor { get }
  static var textPrimary: UIColor { get }
  static var textSecondary: UIColor { get }
  static var textTertiary: UIColor { get }
  
  static var accentBlue: UIColor { get }
  static var accentGreen: UIColor { get }
  static var accentRed: UIColor { get }
  static var accentOrange: UIColor { get }
  static var accentPurple: UIColor { get }
  
  static var constantTonBlue: UIColor { get }
}
