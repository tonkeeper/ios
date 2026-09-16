import Foundation

public enum LighterAPIEnvironment: String, CaseIterable {
    case production
    case testnet
}

public protocol TKAppSettings: AnyObject {
    var isTetraWalletEnabled: Bool { get set }
    var isConfirmButtonInsteadSlider: Bool { get set }
    var lighterAPIEnvironment: LighterAPIEnvironment { get set }
    var raffleIsNewUser: Bool? { get }
    var pendingRaffleIsNewUser: Bool? { get }
    func beginRaffleUserResolution(isNewUser: Bool)
    func cancelPendingRaffleUserResolution()
    /// Persists the first resolved cohort and ignores later attempts to change it.
    func resolveRaffleIsNewUser(_ isNewUser: Bool)
    /// QA-only raffle clock override sent as `_debug_now`: the backend then resolves the
    /// active phase and `{days_left}` copy against this instant. Ignored by prod pods.
    var raffleDebugNow: Date? { get set }
}

public final class UserDefaultsTKAppSettings: TKAppSettings {
    private enum Keys {
        static let isTetraWalletEnabled = "isTetraWalletEnabled"
        static let isConfirmButtonInsteadSlider = "isConfirmButtonInsteadSlider"
        static let lighterAPIEnvironment = "lighterAPIEnvironment"
        static let raffleIsNewUser = "raffleIsNewUserV2"
        static let pendingRaffleIsNewUser = "pendingRaffleIsNewUserV2"
        static let raffleDebugNow = "raffleDebugNow"
    }

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(
        userDefaults: UserDefaults? = nil
    ) {
        self.userDefaults = userDefaults ?? .tkFeatureFlagsDefaults
    }

    public var isTetraWalletEnabled: Bool {
        get {
            userDefaults.bool(forKey: Keys.isTetraWalletEnabled)
        }
        set {
            userDefaults.setValue(newValue, forKey: Keys.isTetraWalletEnabled)
        }
    }

    public var isConfirmButtonInsteadSlider: Bool {
        get {
            userDefaults.bool(forKey: Keys.isConfirmButtonInsteadSlider)
        }
        set {
            userDefaults.setValue(newValue, forKey: Keys.isConfirmButtonInsteadSlider)
        }
    }

    public var lighterAPIEnvironment: LighterAPIEnvironment {
        get {
            userDefaults
                .string(forKey: Keys.lighterAPIEnvironment)
                .flatMap(LighterAPIEnvironment.init(rawValue:)) ?? .production
        }
        set {
            userDefaults.setValue(newValue.rawValue, forKey: Keys.lighterAPIEnvironment)
        }
    }

    public var raffleIsNewUser: Bool? {
        lock.lock()
        defer { lock.unlock() }
        guard userDefaults.object(forKey: Keys.raffleIsNewUser) != nil else { return nil }
        return userDefaults.bool(forKey: Keys.raffleIsNewUser)
    }

    public var pendingRaffleIsNewUser: Bool? {
        lock.lock()
        defer { lock.unlock() }
        guard userDefaults.object(forKey: Keys.pendingRaffleIsNewUser) != nil else { return nil }
        return userDefaults.bool(forKey: Keys.pendingRaffleIsNewUser)
    }

    public func beginRaffleUserResolution(isNewUser: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard userDefaults.object(forKey: Keys.raffleIsNewUser) == nil else { return }
        userDefaults.set(isNewUser, forKey: Keys.pendingRaffleIsNewUser)
    }

    public func cancelPendingRaffleUserResolution() {
        lock.lock()
        defer { lock.unlock() }
        userDefaults.removeObject(forKey: Keys.pendingRaffleIsNewUser)
    }

    public func resolveRaffleIsNewUser(_ isNewUser: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if userDefaults.object(forKey: Keys.raffleIsNewUser) == nil {
            userDefaults.set(isNewUser, forKey: Keys.raffleIsNewUser)
        }
        userDefaults.removeObject(forKey: Keys.pendingRaffleIsNewUser)
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
