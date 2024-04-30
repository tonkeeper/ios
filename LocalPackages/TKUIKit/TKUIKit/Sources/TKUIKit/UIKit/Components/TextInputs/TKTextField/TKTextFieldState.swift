import UIKit

public enum TKTextFieldState {
  case inactive
  case active
  case error
  
  var backgroundColor: UIColor {
    switch self {
    case .inactive:
      return .Field.background
    case .active:
      return .Field.background
    case .error:
      return .Field.errorBackground
    }
  }
  
  var borderColor: UIColor {
    switch self {
    case .inactive:
      return UIColor.clear
    case .active:
      return UIColor.Field.activeBorder
    case .error:
      return UIColor.Field.errorBorder
    }
  }
  
  var tintColor: UIColor {
    switch self {
    case .active:
      return .Accent.blue
    case .inactive:
      return .Accent.blue
    case .error:
      return .Accent.red
    }
  }
}
