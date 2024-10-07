import UIKit

public enum TKActionButtonCategory {
  case primary
  case secondary
  case tertiary
  case overlay
  
  public var titleColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryForeground
    case .secondary: return UIColor.Button.secondaryForeground
    case .tertiary: return UIColor.Button.tertiaryForeground
    case .overlay: return UIColor.Button.overlayForeground
    }
  }
  public var backgroundColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryBackground
    case .secondary: return UIColor.Button.secondaryBackground
    case .tertiary: return UIColor.Button.tertiaryBackground
    case .overlay: return UIColor.Button.overlayBackground
    }
  }
  public var highlightedBackgroundColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryBackgroundHighlighted
    case .secondary: return UIColor.Button.secondaryBackgroundHighlighted
    case .tertiary: return UIColor.Button.tertiaryBackgroundHighlighted
    case .overlay: return       UIColor.Button.overlayBackground.withAlphaComponent(0.7)
    }
  }
  public var disabledTitleColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryForeground.withAlphaComponent(0.48)
    case .secondary: return UIColor.Button.secondaryForeground.withAlphaComponent(0.48)
    case .tertiary: return UIColor.Button.tertiaryForeground.withAlphaComponent(0.48)
    case .overlay: return
      UIColor.Button.overlayForeground.withAlphaComponent(0.48)
    }
  }
  public var disabledBackgroundColor: UIColor {
    switch self {
    case .primary: return UIColor.Button.primaryBackgroundDisabled
    case .secondary: return UIColor.Button.secondaryBackgroundDisabled
    case .tertiary: return UIColor.Button.tertiaryBackgroundDisabled
    case .overlay: return UIColor.Button.overlayBackgroundDisabled
    }
  }
}
