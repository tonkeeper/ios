import UIKit

public enum TKActionButtonCategory {
  case primary
  case secondary
  case tertiary
  case overlay
  
  public var titleColor: UIColor {
    switch self {
    case .primary:   return .Button.primaryForeground
    case .secondary: return .Button.secondaryForeground
    case .tertiary:  return .Button.tertiaryForeground
    case .overlay:   return .Button.overlayForeground
    }
  }
  public var backgroundColor: UIColor {
    switch self {
    case .primary:   return .Button.primaryBackground
    case .secondary: return .Button.secondaryBackground
    case .tertiary:  return .Button.tertiaryBackground
    case .overlay:   return .Button.overlayBackground
    }
  }
  public var highlightedBackgroundColor: UIColor {
    switch self {
    case .primary:   return .Button.primaryBackgroundHighlighted
    case .secondary: return .Button.secondaryBackgroundHighlighted
    case .tertiary:  return .Button.tertiaryBackgroundHighlighted
    case .overlay:   return .Button.overlayBackground.withAlphaComponent(0.7)
    }
  }
  public var disabledTitleColor: UIColor {
    switch self {
    case .primary:   return .Button.primaryForeground.withAlphaComponent(0.48)
    case .secondary: return .Button.secondaryForeground.withAlphaComponent(0.48)
    case .tertiary:  return .Button.tertiaryForeground.withAlphaComponent(0.48)
    case .overlay:   return .Button.overlayForeground.withAlphaComponent(0.48)
    }
  }
  public var disabledBackgroundColor: UIColor {
    switch self {
    case .primary:   return .Button.primaryBackgroundDisabled
    case .secondary: return .Button.secondaryBackgroundDisabled
    case .tertiary:  return .Button.tertiaryBackgroundDisabled
    case .overlay:   return .Button.overlayBackgroundDisabled
    }
  }
}
