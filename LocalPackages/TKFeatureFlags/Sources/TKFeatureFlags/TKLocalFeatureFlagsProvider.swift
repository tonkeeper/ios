import UIKit
internal import TKAppInfo

public enum LocalFeatureFlag: String, CaseIterable {
    case isConfirmButtonInsteadSlider
    case isTetraWalletEnabled
    case sendStatsImmediately
    case minimumLogSeverity

    var key: String {
        self.rawValue
    }
}

public protocol TKLocalFeatureFlagsProvider: AnyObject {
    var isConfirmButtonInsteadSlider: Bool { get set }
    var isTetraWalletEnabled: Bool { get set }
    var sendStatsImmediately: Bool? { get set }
    var minimumLogSeverityRawValue: Int? { get set }

    func addObserver<T: AnyObject>(_ observer: T, flags: Set<LocalFeatureFlag>, closure: @escaping (T, LocalFeatureFlag) -> Void)
}

final class UserDefaultsLocalFeatureFlagsProvider: TKLocalFeatureFlagsProvider {
    private let userDefault: UserDefaults

    private var observers = [LocalFeatureFlag: [UUID: (LocalFeatureFlag) -> Void]]()

    init() {
        self.userDefault = UserDefaults(suiteName: "featureFlags.tkFeatureFlags.tonkeeper") ?? .standard
    }

    var isConfirmButtonInsteadSlider: Bool {
        get {
            userDefault.bool(forKey: LocalFeatureFlag.isConfirmButtonInsteadSlider.key)
        }
        set {
            userDefault.setValue(newValue, forKey: LocalFeatureFlag.isConfirmButtonInsteadSlider.key)
        }
    }

    var isTetraWalletEnabled: Bool {
        get {
            userDefault.bool(forKey: LocalFeatureFlag.isTetraWalletEnabled.key)
        }
        set {
            userDefault.setValue(newValue, forKey: LocalFeatureFlag.isTetraWalletEnabled.key)
        }
    }

    var sendStatsImmediately: Bool? {
        get {
            guard isDevOverridesEnabled else {
                return nil
            }
            guard let value = userDefault.object(forKey: LocalFeatureFlag.sendStatsImmediately.key) as? NSNumber else {
                return nil
            }
            return value.boolValue
        }
        set {
            guard isDevOverridesEnabled else {
                return
            }
            if let newValue {
                userDefault.setValue(newValue, forKey: LocalFeatureFlag.sendStatsImmediately.key)
            } else {
                userDefault.removeObject(forKey: LocalFeatureFlag.sendStatsImmediately.key)
            }
        }
    }

    var minimumLogSeverityRawValue: Int? {
        get {
            guard isDevOverridesEnabled else {
                return nil
            }
            guard let value = userDefault.object(forKey: LocalFeatureFlag.minimumLogSeverity.key) as? NSNumber else {
                return nil
            }
            return value.intValue
        }
        set {
            guard isDevOverridesEnabled else {
                return
            }
            if let newValue {
                userDefault.setValue(newValue, forKey: LocalFeatureFlag.minimumLogSeverity.key)
            } else {
                userDefault.removeObject(forKey: LocalFeatureFlag.minimumLogSeverity.key)
            }
        }
    }

    private var isDevOverridesEnabled: Bool {
        !UIApplication.shared.isAppStoreEnvironment
    }

    func addObserver<T: AnyObject>(_ observer: T, flags: Set<LocalFeatureFlag>, closure: @escaping (T, LocalFeatureFlag) -> Void) {
        let id = UUID()
        let closure: (LocalFeatureFlag) -> Void = { [weak self, weak observer] flag in
            guard let self else { return }
            var flagObservers = observers[flag]
            guard let observer else {
                flagObservers?.removeValue(forKey: id)
                observers[flag] = flagObservers
                return
            }
            closure(observer, flag)
        }
        let action = {
            for flag in flags {
                var flagObservers = self.observers[flag] ?? [UUID: (LocalFeatureFlag) -> Void]()
                flagObservers[id] = closure
                self.observers[flag] = flagObservers
            }
        }
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }
}
