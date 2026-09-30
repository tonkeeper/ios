import Foundation

public enum FeatureFlag: CaseIterable, Hashable {
    case inAppReviewEnabled
    case mnemonicsStorageV2
    case perpsEnabled
    case swapKitEnabled
    case analyticsPersistentCache
}

public extension FeatureFlag {
    var localKey: String {
        switch self {
        case .inAppReviewEnabled:
            "inAppReviewEnabled"
        case .mnemonicsStorageV2:
            "mnemonicsStorageV2"
        case .perpsEnabled:
            "perpsEnabled"
        case .swapKitEnabled:
            "swapKitEnabled"
        case .analyticsPersistentCache:
            "analyticsPersistentCache"
        }
    }

    var remoteKey: String? {
        switch self {
        case .inAppReviewEnabled:
            "ios_in_app_review_enabled"
        case .mnemonicsStorageV2:
            "ios_mnemonic_storage_v2"
        case .perpsEnabled:
            "ios_perps_enabled"
        case .swapKitEnabled:
            "ios_swapkit_enabled"
        case .analyticsPersistentCache:
            "ios_analytics_persistent_cache"
        }
    }

    var defaultValue: Bool {
        switch self {
        case .inAppReviewEnabled:
            false
        case .mnemonicsStorageV2:
            false
        case .perpsEnabled:
            false
        case .swapKitEnabled:
            false
        case .analyticsPersistentCache:
            false
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
