import UIKit

public enum TKTheme: String, CaseIterable {
  case deepBlue
  case dark
  case light
  case system
  
  public var title: String {
    switch self {
    case .deepBlue:
      return "Deep Blue"
    case .dark:
      return "Dark"
    case .light:
      return "Light"
    case .system:
      return "System"
    }
  }
  
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
  
  var themeAppaearance: TKThemeAppearance {
    switch self {
    case .deepBlue:
      return DeepBlueThemeAppearance()
    case .dark:
      return DarkThemeAppearance()
    case .light:
      return LightThemeAppearance()
    case .system:
      return SystemThemeAppearance()
    }
  }
}

public final class TKThemeManager {
  public typealias didUpdateThemeClosure = (TKTheme) -> Void
  
  public var theme: TKTheme {
    didSet {
      didUpdateTheme()
    }
  }
  
  public static let shared = TKThemeManager()
  
  public private(set) var themeAppearance: TKThemeAppearance
  
  private let userDefaults = UserDefaults(suiteName: "TKUIKit")
  
  init() {
    guard let themeIdentifier = userDefaults?.string(forKey: .themeKey),
          let theme = TKTheme(rawValue: themeIdentifier) else {
      self.theme = .light
      self.themeAppearance = LightThemeAppearance()
      return
    }
    self.theme = theme
    self.themeAppearance = theme.themeAppaearance
  }
  
  private var observations = [UUID: didUpdateThemeClosure]()
  
  public func addEventObserver<T: AnyObject>(_ observer: T,
                                             closure: @escaping (T, TKTheme) -> Void) {
    let id = UUID()
    let eventHandler: (TKTheme) -> Void = { [weak self, weak observer] theme in
      guard let self else { return }
      guard let observer else {
        observations.removeValue(forKey: id)
        return
      }
      
      closure(observer, theme)
    }
    observations[id] = eventHandler
  }
  
  private func didUpdateTheme() {
    themeAppearance = theme.themeAppaearance
    userDefaults?.setValue(theme.rawValue, forKey: .themeKey)
    observations.forEach { $0.value(theme) }
  }
}

private extension String {
  static let themeKey = "TKThemeIdentifier"
}
