import Foundation

public struct SettingsVault<Key: CustomStringConvertible> {
  private let userDefaults: UserDefaults
  
  public init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
  }
  
  public func value<T>(key: Key) -> T? {
    userDefaults.value(forKey: key.description) as? T
  }
  
  public func setValue<T>(_ value: T, key: Key) {
    userDefaults.setValue(value, forKey: key.description)
  }
}
