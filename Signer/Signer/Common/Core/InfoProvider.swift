import Foundation

struct InfoProvider {
  enum Keys: String {
    case appVersion = "CFBundleShortVersionString"
    case buildVersion = "CFBundleVersion"
    case supportURL = "SupportURL"
  }
  
  static func value<T>(key: Keys) -> T? {
    Bundle.main.object(forInfoDictionaryKey: key.rawValue) as? T
  }
  
  static func supportURL() -> URL? {
    guard let value: String = self.value(key: .supportURL) else { return nil }
    return URL(string: value)
  }
  
  static func appVersion() -> String? {
    self.value(key: .appVersion)
  }
  
  static func buildVersion() -> String? {
    self.value(key: .buildVersion)
  }
}
