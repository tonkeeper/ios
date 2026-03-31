import UIKit
internal import TKAppInfo

public protocol TKLocalFeatureFlagsProvider: AnyObject {
    subscript(key: String) -> Bool? { get set }
}

final class UserDefaultsLocalFeatureFlagsProvider: TKLocalFeatureFlagsProvider {
    private let userDefault: UserDefaults
    private let isDevOverridesEnabled: Bool

    init(
        userDefault: UserDefaults,
        isDevOverridesEnabled: Bool
    ) {
        self.userDefault = userDefault
        self.isDevOverridesEnabled = isDevOverridesEnabled
    }

    subscript(key: String) -> Bool? {
        get {
            guard isDevOverridesEnabled else {
                return nil
            }
            guard let value = userDefault.object(forKey: key) as? NSNumber else {
                return nil
            }
            return value.boolValue
        }
        set {
            guard isDevOverridesEnabled else {
                return
            }
            if let newValue {
                userDefault.setValue(newValue, forKey: key)
            } else {
                userDefault.removeObject(forKey: key)
            }
        }
    }
}
