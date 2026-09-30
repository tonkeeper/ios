import Foundation

public protocol TKAppSettings: AnyObject {
    var isConfirmButtonInsteadSlider: Bool { get set }
    /// Raffle cohort resolved once at launch: `true` when no non-multichain wallet existed then.
    var raffleIsNewUser: Bool? { get set }
    /// QA-only raffle clock override sent as `_debug_now`: the backend then resolves the
    /// active phase and `{days_left}` copy against this instant. Ignored by prod pods.
    var raffleDebugNow: Date? { get set }
}

public final class UserDefaultsTKAppSettings: TKAppSettings {
    private enum Keys {
        static let isConfirmButtonInsteadSlider = "isConfirmButtonInsteadSlider"
        static let raffleIsNewUser = "raffleIsNewUserV2"
        static let raffleDebugNow = "raffleDebugNow"
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

    public var raffleDebugNow: Date? {
        get {
            userDefaults.object(forKey: Keys.raffleDebugNow) as? Date
        }
        set {
            if let newValue {
                userDefaults.setValue(newValue, forKey: Keys.raffleDebugNow)
            } else {
                userDefaults.removeObject(forKey: Keys.raffleDebugNow)
            }
        }
    }
}
