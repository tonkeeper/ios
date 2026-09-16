import Foundation
import TKTradingAPI

public enum TradingVerification: String, Hashable, Sendable, Codable {
    case trusted
    case whitelist
    case none
    case blacklist

    public var isTrusted: Bool {
        self == .trusted
    }

    public var isVerified: Bool {
        switch self {
        case .trusted, .whitelist:
            true
        case .none, .blacklist:
            false
        }
    }

    public var isUnverified: Bool {
        !isVerified
    }

    public var isScam: Bool {
        self == .blacklist
    }
}

public extension TradingVerification {
    init(api: Components.Schemas.AssetRef.verificationPayload) {
        switch api {
        case .trusted:
            self = .trusted
        case .whitelist:
            self = .whitelist
        case .none:
            self = .none
        case .blacklist:
            self = .blacklist
        }
    }

    init(api: Components.Schemas.AssetRefSummary.verificationPayload) {
        switch api {
        case .trusted:
            self = .trusted
        case .whitelist:
            self = .whitelist
        case .none:
            self = .none
        case .blacklist:
            self = .blacklist
        }
    }
}
