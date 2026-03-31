import UIKit

public final class TKFeatureFlagsImplementation {
    fileprivate static var isDevOverridesEnabled: Bool {
        !UIApplication.shared.isAppStoreEnvironment
    }

    private let localProvider: TKLocalFeatureFlagsProvider
    private let remoteConfigProvider: RemoteConfigProvider

    public init(
        localProvider: TKLocalFeatureFlagsProvider,
        remoteConfigProvider: RemoteConfigProvider
    ) {
        self.localProvider = localProvider
        self.remoteConfigProvider = remoteConfigProvider
    }

    public convenience init(remoteConfigProvider: RemoteConfigProvider) {
        self.init(
            localProvider: UserDefaultsLocalFeatureFlagsProvider(
                userDefault: .tkFeatureFlagsDefaults,
                isDevOverridesEnabled: Self.isDevOverridesEnabled
            ),
            remoteConfigProvider: remoteConfigProvider
        )
    }
}

// MARK: Feature Flags

extension TKFeatureFlagsImplementation: TKFeatureFlags {
    public subscript(flag: FeatureFlag) -> Bool {
        get {
            let localValue = localProvider[flag.localKey]
            if let localValue {
                return localValue
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

    public func resetValue(for flag: FeatureFlag) {
        localProvider[flag.localKey] = nil
    }

    public func loadRemoteConfig() async {
        await remoteConfigProvider.load()
    }

    public var allValues: [FeatureFlag: FeatureFlagValue] {
        return FeatureFlag.allCases.reduce(into: [:]) { dict, flag in
            dict[flag] = FeatureFlagValue(
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
}
