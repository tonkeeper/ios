import Foundation

public struct SettingsVault<Key: CustomStringConvertible> {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public func value(key: Key) -> Data? {
        userDefaults.data(forKey: key.description)
    }

    public func value<T>(key: Key) -> T? {
        userDefaults.value(forKey: key.description) as? T
    }

    public func setValue<T>(_ value: T, key: Key) {
        userDefaults.setValue(value, forKey: key.description)
    }

    public func setValue(_ value: Data, key: Key) {
        userDefaults.set(value, forKey: key.description)
    }
}
