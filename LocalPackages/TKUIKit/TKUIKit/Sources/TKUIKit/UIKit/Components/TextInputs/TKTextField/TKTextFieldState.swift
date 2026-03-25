import UIKit

public enum TKTextFieldState {
    case inactive
    case active
    case error

    public var backgroundColor: UIColor {
        switch self {
        case .inactive:
            return .Background.content
        case .active:
            return .Field.background
        case .error:
            return .Field.errorBackground
        }
    }

    public var borderColor: UIColor {
        switch self {
        case .inactive:
            return UIColor.clear
        case .active:
            return UIColor.Field.activeBorder
        case .error:
            return UIColor.Field.errorBorder
        }
    }

    public var tintColor: UIColor {
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
