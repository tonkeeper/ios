import UIKit

public enum TKButtonCategory {
  case primary
  case secondary
  case tertiary
  
  var titleColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryForeground
    case .secondary: return UIColor.Button.secondaryForeground
    case .tertiary: return UIColor.Button.tertiaryForeground
    }
  }
  var backgroundColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryBackground
    case .secondary: return UIColor.Button.secondaryBackground
    case .tertiary: return UIColor.Button.tertiaryBackground
    }
  }
  var highlightedBackgroundColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryBackgroundHighlighted
    case .secondary: return UIColor.Button.secondaryBackgroundHighlighted
    case .tertiary: return UIColor.Button.tertiaryBackgroundHighlighted
    }
  }
  var disabledTitleColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryForeground.withAlphaComponent(0.48)
    case .secondary: return UIColor.Button.secondaryForeground.withAlphaComponent(0.48)
    case .tertiary: return UIColor.Button.tertiaryForeground.withAlphaComponent(0.48)
    }
  }
  var disabledBackgroundColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryBackgroundDisabled
    case .secondary: return UIColor.Button.secondaryBackgroundDisabled
    case .tertiary: return UIColor.Button.tertiaryBackgroundDisabled
    }
  }
}

