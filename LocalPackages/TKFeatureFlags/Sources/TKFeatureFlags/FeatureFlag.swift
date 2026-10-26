import Foundation

public enum FeatureFlag: CaseIterable, Hashable {
    case inAppReviewEnabled
    case mnemonicsStorageV2
    case perpsEnabled
    case swapKitEnabled
    case analyticsPersistentCache
    case earnEnabled
    case tonConnectSignMessageEnabled
    case moonpayRampEnabled
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
        case .earnEnabled:
            "earnEnabled"
        case .tonConnectSignMessageEnabled:
            "tonConnectSignMessageEnabled"
        case .moonpayRampEnabled:
            "moonpayRampEnabled"
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
        case .earnEnabled:
            "ios_earn_enabled"
        case .tonConnectSignMessageEnabled:
            "ios_tonconnect_sign_message_enabled"
        case .moonpayRampEnabled:
            "ios_moonpay_ramp_enabled"
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
        case .earnEnabled:
            false
        case .tonConnectSignMessageEnabled:
            true
        case .moonpayRampEnabled:
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

public extension FeatureFlagValue {
    var source: String {
        if bundleValue != nil {
            "bundle"
        } else if localValue != nil {
            "local"
        } else if remoteValue != nil {
            "remote"
        } else {
            "default"
        }
    }
}
