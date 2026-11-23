import Foundation

public enum FeatureFlag: CaseIterable, Hashable {
    case inAppReviewEnabled
    case perpsEnabled
    case perpsBatteryFeeEnabled
    /// The battery's relayer pays Solana fees: transfers and swaps on Solana offer charges and the tokens it takes.
    case solanaGaslessEnabled
    case perpsRealtimeEnabled
    /// Generic Payload: the wallet's own sends and dApp transactions and messages signed as the chain-kit
    /// operation each is reviewed as, and swaps on the v3 crosschain API, which answers with one.
    case genericPayloadEnabled
    case swapKitEnabled
    case swapExactOutputEnabled
    case nativeSwapEmulationEnabled
    case earnEnabled
    case predictEnabled
    case tonConnectSignMessageEnabled
    case moonpayRampEnabled
    case ledgerMultichain
    case ledgerMigration
    case liquidGlassEnabled
    case liveActivitiesEnabled
    case liveActivityPushUpdatesEnabled
    case loyaltyEnabled
    case numPadEnabled
}

public extension FeatureFlag {
    var localKey: String {
        switch self {
        case .inAppReviewEnabled:
            "inAppReviewEnabled"
        case .perpsEnabled:
            "perpsEnabled"
        case .perpsBatteryFeeEnabled:
            "perpsBatteryFeeEnabled"
        case .solanaGaslessEnabled:
            "solanaGaslessEnabled"
        case .perpsRealtimeEnabled:
            "perpsRealtimeEnabled"
        case .genericPayloadEnabled:
            "genericPayloadEnabled"
        case .swapKitEnabled:
            "swapKitEnabled"
        case .swapExactOutputEnabled:
            "swapExactOutputEnabled"
        case .nativeSwapEmulationEnabled:
            "nativeSwapEmulationEnabled"
        case .earnEnabled:
            "earnEnabled"
        case .predictEnabled:
            "predictEnabled"
        case .tonConnectSignMessageEnabled:
            "tonConnectSignMessageEnabled"
        case .moonpayRampEnabled:
            "moonpayRampEnabled"
        case .ledgerMultichain:
            "ledgerMultichain"
        case .ledgerMigration:
            "ledgerMigration"
        case .liquidGlassEnabled:
            "liquidGlassEnabled"
        case .liveActivitiesEnabled:
            "liveActivitiesEnabled"
        case .liveActivityPushUpdatesEnabled:
            "liveActivityPushUpdatesEnabled"
        case .loyaltyEnabled:
            "loyaltyEnabled"
        case .numPadEnabled:
            "numPadEnabled"
        }
    }

    var remoteKey: String? {
        switch self {
        case .inAppReviewEnabled:
            "ios_in_app_review_enabled"
        case .perpsEnabled:
            "ios_perps_enabled"
        case .perpsBatteryFeeEnabled:
            "ios_perps_battery_fee_enabled"
        case .solanaGaslessEnabled:
            "ios_solana_gasless_enabled"
        case .perpsRealtimeEnabled:
            "ios_perps_realtime_enabled"
        case .genericPayloadEnabled:
            "ios_generic_payload_enabled"
        case .swapKitEnabled:
            "ios_swapkit_enabled"
        case .swapExactOutputEnabled:
            "ios_is_swap_exact_output_enabled"
        case .nativeSwapEmulationEnabled:
            "ios_native_swap_emulation_enabled"
        case .earnEnabled:
            "ios_earn_enabled"
        case .predictEnabled:
            "ios_predict_enabled"
        case .tonConnectSignMessageEnabled:
            "ios_tonconnect_sign_message_enabled"
        case .moonpayRampEnabled:
            "ios_moonpay_ramp_enabled"
        case .ledgerMultichain:
            "ios_is_ledger_multichain_enabled"
        case .ledgerMigration:
            "ios_ledger_migration_enabled"
        case .liquidGlassEnabled:
            "ios_liquid_glass_enabled"
        case .liveActivitiesEnabled:
            "ios_live_activities_enabled"
        case .liveActivityPushUpdatesEnabled:
            "ios_live_activity_push_enabled"
        case .loyaltyEnabled:
            "ios_is_loyalty_enabled"
        case .numPadEnabled:
            "ios_num_pad_enabled"
        }
    }

    var defaultValue: Bool {
        switch self {
        case .inAppReviewEnabled:
            false
        case .perpsEnabled:
            false
        case .perpsBatteryFeeEnabled:
            false
        case .solanaGaslessEnabled:
            false
        case .perpsRealtimeEnabled:
            #if DEBUG
                true
            #else
                false
            #endif
        case .genericPayloadEnabled:
            false
        case .swapKitEnabled:
            false
        case .swapExactOutputEnabled:
            false
        case .nativeSwapEmulationEnabled:
            false
        case .earnEnabled:
            false
        case .predictEnabled:
            false
        case .tonConnectSignMessageEnabled:
            true
        case .moonpayRampEnabled:
            false
        case .ledgerMultichain:
            false
        case .ledgerMigration:
            false
        case .liquidGlassEnabled:
            #if DEBUG
                true
            #else
                false
            #endif
        case .liveActivitiesEnabled:
            false
        case .liveActivityPushUpdatesEnabled:
            false
        case .loyaltyEnabled:
            false
        case .numPadEnabled:
            #if DEBUG
                true
            #else
                false
            #endif
        }
    }

    /// The flag this one only works on top of: it reads as off while that one is off, whatever its own value.
    var requirement: FeatureFlag? {
        switch self {
        case .ledgerMigration:
            .ledgerMultichain
        case .perpsRealtimeEnabled:
            .perpsEnabled
        default:
            nil
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
