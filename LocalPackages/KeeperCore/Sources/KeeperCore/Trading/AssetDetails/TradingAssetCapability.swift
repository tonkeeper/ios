import Foundation

public enum TradingAssetCapability: String, Equatable, Sendable, Codable, Hashable {
    case onramp
    case offramp
    case swap
    case p2p
}

public extension Set where Element == TradingAssetCapability {
    var supportsSwap: Bool {
        contains(.swap)
    }

    var supportsOfframp: Bool {
        contains(.offramp)
    }

    var supportsOnramp: Bool {
        contains(.onramp)
    }
}
