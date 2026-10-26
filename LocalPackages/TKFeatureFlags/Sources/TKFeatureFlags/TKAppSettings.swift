import Foundation

public protocol TKAppSettings: AnyObject {
    var isConfirmButtonInsteadSlider: Bool { get set }
    /// Raffle cohort resolved once at launch: `true` when no non-multichain wallet existed then.
    var raffleIsNewUser: Bool? { get set }
}

public final class UserDefaultsTKAppSettings: TKAppSettings {
    private enum Keys {
        static let isConfirmButtonInsteadSlider = "isConfirmButtonInsteadSlider"
        static let raffleIsNewUser = "raffleIsNewUserV2"
    }

    private let userDefaults: UserDefaults

    public init(
        userDefaults: UserDefaults? = nil
    ) {
        self.userDefaults = userDefaults ?? .tkFeatureFlagsDefaults
    }

    public var isConfirmButtonInsteadSlider: Bool {
        get {
            userDefaults.bool(forKey: Keys.isConfirmButtonInsteadSlider)
        }
        set {
            userDefaults.setValue(newValue, forKey: Keys.isConfirmButtonInsteadSlider)
        }
    }

    public var raffleIsNewUser: Bool? {
        get {
            userDefaults.object(forKey: Keys.raffleIsNewUser) as? Bool
        }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: Keys.raffleIsNewUser)
            } else {
                userDefaults.removeObject(forKey: Keys.raffleIsNewUser)
            }
        }
    }
}
