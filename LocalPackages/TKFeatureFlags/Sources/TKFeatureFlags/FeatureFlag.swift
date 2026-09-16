import Foundation

public enum FeatureFlag: CaseIterable, Hashable {
    case inAppReviewEnabled
    case walletKitEnabled
    case multichainEnabled
    case importMultichainEnabled
    case mnemonicsStorageV2
    case perpsEnabled
    case mysteryRaffleEnabled
    case migrationEnabled
    case migrationBatteryDisabled
    case swapKitEnabled
    case analyticsPersistentCache
    case realtimeEnabled
}

public extension FeatureFlag {
    var localKey: String {
        switch self {
        case .inAppReviewEnabled:
            "inAppReviewEnabled"
        case .walletKitEnabled:
            "walletKitEnabled"
        case .multichainEnabled:
            "multichainEnabled"
        case .importMultichainEnabled:
            "importMultichainEnabled"
        case .mnemonicsStorageV2:
            "mnemonicsStorageV2"
        case .perpsEnabled:
            "perpsEnabled"
        case .mysteryRaffleEnabled:
            "mysteryRaffleEnabled"
        case .migrationEnabled:
            "migrationEnabled"
        case .migrationBatteryDisabled:
            "migrationBatteryDisabled"
        case .swapKitEnabled:
            "swapKitEnabled"
        case .analyticsPersistentCache:
            "analyticsPersistentCache"
        case .realtimeEnabled:
            "realtimeEnabled"
        }
    }

    var remoteKey: String? {
        switch self {
        case .inAppReviewEnabled:
            "ios_in_app_review_enabled"
        case .walletKitEnabled:
            "ios_wallet_kit_enabled"
        case .multichainEnabled:
            "ios_multichain_enabled"
        case .importMultichainEnabled:
            "ios_import_multichain_enabled"
        case .mnemonicsStorageV2:
            "ios_mnemonic_storage_v2"
        case .perpsEnabled:
            "ios_perps_enabled"
        case .mysteryRaffleEnabled:
            "ios_mystery_raffle_enabled"
        case .migrationEnabled:
            "ios_migration_enabled"
        case .migrationBatteryDisabled:
            "ios_migration_battery_disabled"
        case .swapKitEnabled:
            "ios_swapkit_enabled"
        case .analyticsPersistentCache:
            "ios_analytics_persistent_cache"
        case .realtimeEnabled:
            "ios_is_realtime_enabled"
        }
    }

    var defaultValue: Bool {
        switch self {
        case .inAppReviewEnabled:
            false
        case .walletKitEnabled:
            false
        case .multichainEnabled:
            true
        case .importMultichainEnabled:
            true
        case .mnemonicsStorageV2:
            false
        case .perpsEnabled:
            false
        case .mysteryRaffleEnabled:
            false
        case .migrationEnabled:
            false
        case .migrationBatteryDisabled:
            false
        case .swapKitEnabled:
            false
        case .analyticsPersistentCache:
            false
        case .realtimeEnabled:
            true
        }
    }
}

public struct FeatureFlagValue {
    public var bundleValue: Bool?
    public var localValue: Bool?
    public var remoteValue: Bool?
    public var defaultValue: Bool
    public var resolvedValue: Bool
}
