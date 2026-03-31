import Foundation

public protocol TKAppSettings: AnyObject {
    var isTetraWalletEnabled: Bool { get set }
    var isConfirmButtonInsteadSlider: Bool { get set }
}

public final class UserDefaultsTKAppSettings: TKAppSettings {
    private enum Keys {
        static let isTetraWalletEnabled = "isTetraWalletEnabled"
        static let isConfirmButtonInsteadSlider = "isConfirmButtonInsteadSlider"
    }

    private let userDefaults: UserDefaults

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
}
