import UIKit

public protocol ColorScheme {
  var backgroundContentAttention: UIColor { get }
  var backgroundContentTint: UIColor { get }
  var backgroundContent: UIColor { get }
  var backgroundHighlighted: UIColor { get }
  var backgroundOverlayExtraLight: UIColor { get }
  var backgroundOverlayLight: UIColor { get }
  var backgroundOverlayStrong: UIColor { get }
  var backgroundPage: UIColor { get }
  var backgroundTransparent: UIColor { get }
  var backgroundContentPlaceholder: UIColor { get }
  
  var buttonPrimaryBackgroundDisabled: UIColor { get }
  var buttonPrimaryBackgroundHighlighted: UIColor { get }
  var buttonPrimaryBackground: UIColor { get }
  var buttonPrimaryForeground: UIColor { get }
  var buttonSecondaryBackgroundDisabled: UIColor { get }
  var buttonSecondaryBackgroundHighlighted: UIColor { get }
  var buttonSecondaryBackground: UIColor { get }
  var buttonSecondaryForeground: UIColor { get }
  var buttonTertiaryBackgroundDisabled: UIColor { get }
  var buttonTertiaryBackgroundHighlighted: UIColor { get }
  var buttonTertiaryBackground: UIColor { get }
  var buttonTertiaryForeground: UIColor { get }
  var buttonPrimaryBackgroundGreen: UIColor { get }
  var buttonPrimaryBackgroundGreenHighlighted: UIColor { get }
  var buttonPrimaryBackgroundGreenDisabled: UIColor { get }

  var fieldActiveBorder: UIColor { get }
  var fieldBackground: UIColor { get }
  var fieldErrorBackground: UIColor { get }
  var fieldErrorBorder: UIColor { get }
  
  var iconPrimaryAlternate: UIColor { get }
  var iconPrimary: UIColor { get }
  var iconSecondary: UIColor { get }
  var iconTertiary: UIColor { get }
  
  var separatorAlternate: UIColor { get }
  var separatorCommon: UIColor { get }
  
  var tabBarActiveIcon: UIColor { get }
  var tabBarInactiveIcon: UIColor { get }
  
  var textAccent: UIColor { get }
  var textPrimaryAlternate: UIColor { get }
  var textPrimary: UIColor { get }
  var textSecondary: UIColor { get }
  var textTertiary: UIColor { get }
  
  var accentBlue: UIColor { get }
  var accentGreen: UIColor { get }
  var accentRed: UIColor { get }
  var accentOrange: UIColor { get }
  var accentPurple: UIColor { get }
  
  var bubbleBackground: UIColor { get }
  var bubbleForeground: UIColor { get }

  var constantTonBlue: UIColor { get }
  var constantWhite: UIColor { get }
  var constantBlack: UIColor { get }
}
