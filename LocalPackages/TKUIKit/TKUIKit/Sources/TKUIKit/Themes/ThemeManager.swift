import UIKit

public enum Theme {
  case blue
  case dark
  
  public var userInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .blue:
      return .light
    case .dark:
      return .dark
    }
  }
  
  public var alertUserInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .blue:
      return .dark
    case .dark:
      return .dark
    }
  }
}

public final class ThemeManager {
  public static let shared = ThemeManager()
  
  public var theme: Theme = .blue {
    didSet {
      NotificationCenter.default.post(Notification(name: Notification.Name.didChangeThemeMode))
    }
  }
  
  private init() {
    NotificationCenter.default.post(Notification(name: Notification.Name.didChangeThemeMode))
  }
}
