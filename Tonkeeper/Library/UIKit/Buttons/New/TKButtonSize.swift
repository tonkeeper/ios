import UIKit
import TKUIKit

public enum TKButtonSize {
  case small
  case medium
  case large
  
  var height: CGFloat {
    switch self {
    case .small: return 36
    case .medium: return 48
    case .large: return 56
    }
  }
  
  var cornerRadius: CGFloat {
    switch self {
    case .small: return 18
    case .medium: return 24
    case .large: return 16
    }
  }
  
  var padding: UIEdgeInsets {
    switch self {
    case .small: return .init(top: 8, left: 16, bottom: 8, right: 16)
    case .medium: return .init(top: 11, left: 20, bottom: 13, right: 20)
    case .large: return .init(top: 15, left: 24, bottom: 16, right: 24)
    }
  }
  
  var textStyle: TextStyle {
    switch self {
    case .small: return .label2
    case .medium: return .label1
    case .large: return .label1
    }
  }
}
