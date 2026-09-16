internal import TKAppInfo
import UIKit

public final class TKFeatureFlagsImplementation {
    fileprivate static var isDevOverridesEnabled: Bool {
        !UIApplication.shared.isAppStoreEnvironment
    }

    private let localProvider: TKLocalFeatureFlagsProvider
    private let remoteConfigProvider: RemoteConfigProvider
    private let overrides: [String: Bool]

    public init(
        localProvider: TKLocalFeatureFlagsProvider,
        remoteConfigProvider: RemoteConfigProvider,
        overrides: [String: Bool] = [:]
    ) {
        self.localProvider = localProvider
        self.remoteConfigProvider = remoteConfigProvider
        self.overrides = overrides
    }

    public convenience init(
        remoteConfigProvider: RemoteConfigProvider,
        overrides: [String: Bool] = [:]
    ) {
        self.init(
            localProvider: UserDefaultsLocalFeatureFlagsProvider(
                userDefault: .tkFeatureFlagsDefaults,
                isDevOverridesEnabled: Self.isDevOverridesEnabled
            ),
            remoteConfigProvider: remoteConfigProvider,
            overrides: overrides
        )
    }
}

// MARK: Feature Flags

extension TKFeatureFlagsImplementation: TKFeatureFlags {
    public subscript(flag: FeatureFlag) -> Bool {
        get {
            if let overrideValue = devOverride(for: flag) {
                return overrideValue
            }
            let remoteValue = flag.remoteKey.flatMap { remoteKey in
                remoteConfigProvider[remoteKey]
            }
            if let remoteValue {
                return remoteValue
            }
            return flag.defaultValue
        }
        set {
            localProvider[flag.localKey] = newValue
        }
    }

    public func devOverride(for flag: FeatureFlag) -> Bool? {
        overrides[flag.localKey] ?? localProvider[flag.localKey]
    }

    public func resetValue(for flag: FeatureFlag) {
        localProvider[flag.localKey] = nil
    }

    public func loadRemoteConfig() async {
        await remoteConfigProvider.load()
    }

    public var allValues: [FeatureFlag: FeatureFlagValue] {
        return FeatureFlag.allCases.reduce(into: [:]) { dict, flag in
            dict[flag] = FeatureFlagValue(
                bundleValue: overrides[flag.localKey],
                localValue: localProvider[flag.localKey],
                remoteValue: flag.remoteKey.flatMap { key in
                    remoteConfigProvider[key]
                },
                defaultValue: flag.defaultValue,
                resolvedValue: self[flag]
            )
        }
    }
}

// MARK: - Legacy

public enum TKAppPreferences {
    private static var localFeatureFlagsRepository = UserDefaults.tkFeatureFlagsDefaults
    private static var isDevOverridesEnabled = TKFeatureFlagsImplementation.isDevOverridesEnabled

    enum DevOverrideFlag: String {
        case sendStatsImmediately
        case minimumLogSeverity
        case showTouches
    }

    public static var sendStatsImmediately: Bool? {
        get {
            guard isDevOverridesEnabled else {
                return nil
            }
            guard let value = localFeatureFlagsRepository.object(
                forKey: DevOverrideFlag.sendStatsImmediately.rawValue
            ) as? NSNumber else {
                return nil
            }
            return value.boolValue
        }
        set {
            guard isDevOverridesEnabled else {
                return
            }
            if let newValue {
                localFeatureFlagsRepository.setValue(newValue, forKey: DevOverrideFlag.sendStatsImmediately.rawValue)
            } else {
                localFeatureFlagsRepository.removeObject(forKey: DevOverrideFlag.sendStatsImmediately.rawValue)
            }
        }
    }

    public static var minimumLogSeverityRawValue: Int? {
        get {
            guard isDevOverridesEnabled else {
                return nil
            }
            guard let value = localFeatureFlagsRepository.object(
                forKey: DevOverrideFlag.minimumLogSeverity.rawValue
            ) as? NSNumber else {
                return nil
            }
            return value.intValue
        }
        set {
            guard isDevOverridesEnabled else {
                return
            }
            if let newValue {
                localFeatureFlagsRepository.setValue(newValue, forKey: DevOverrideFlag.minimumLogSeverity.rawValue)
            } else {
                localFeatureFlagsRepository.removeObject(forKey: DevOverrideFlag.minimumLogSeverity.rawValue)
            }
        }
    }

    public static var showTouches: Bool {
        get {
            guard isDevOverridesEnabled else {
                return false
            }
            return localFeatureFlagsRepository.bool(forKey: DevOverrideFlag.showTouches.rawValue)
        }
        set {
            guard isDevOverridesEnabled else {
                return
            }
            localFeatureFlagsRepository.setValue(newValue, forKey: DevOverrideFlag.showTouches.rawValue)
        }
    }
}
