import UIKit

public enum Theme {
  case deepBlue
  case dark
  case light
  case system
  
  public var userInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .deepBlue:
      return .dark
    case .dark:
      return .dark
    case .light:
      return .light
    case .system:
      return .unspecified
    }
  }
  
  public var alertUserInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .deepBlue:
      return .dark
    case .dark:
      return .dark
    case .light:
      return .light
    case .system:
      return .unspecified
    }
  }
}

public final class ThemeManager {
  public static let shared = ThemeManager()
  
  public var theme: Theme = .dark {
    didSet {
      NotificationCenter.default.post(Notification(name: Notification.Name.didChangeThemeMode))
    }
  }
  
  private init() {
    NotificationCenter.default.post(Notification(name: Notification.Name.didChangeThemeMode))
  }
}
