import Foundation

public enum FeatureFlag: CaseIterable, Hashable {
    case walletKitEnabled
    case newRampFlow
}

public extension FeatureFlag {
    var localKey: String {
        switch self {
        case .walletKitEnabled:
            "walletKitEnabled"
        case .newRampFlow:
            "newRampFlow"
        }
    }

    var remoteKey: String? {
        switch self {
        case .walletKitEnabled:
            "walletKitEnabled"
        case .newRampFlow:
            "ios_is_new_ramp_flow_enabled"
        }
    }

    var defaultValue: Bool {
        switch self {
        case .walletKitEnabled:
            false
        case .newRampFlow:
            false
        }
    }
}

public struct FeatureFlagValue {
    public var localValue: Bool?
    public var remoteValue: Bool?
    public var defaultValue: Bool
    public var resolvedValue: Bool
}
