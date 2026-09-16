public enum MultichainSwapAggregator: String, Sendable, Hashable, CaseIterable {
    case swapsXyz = "swapsxyz"
    case swapKit = "swapkit"
    case omniston
}

public extension MultichainSwapAggregator {
    init(aggregator: String) throws(MultichainSwapExecutionFailure) {
        guard let value = Self(rawValue: aggregator) else {
            throw .unsupportedAggregator(aggregator)
        }
        self = value
    }

    /// swaps.xyz and Omniston are signed and broadcast through the same pipeline, so the two collapse
    /// into one provider. Derived rather than carried alongside the aggregator: a route signed as
    /// one provider while reported as another aggregator would be silently wrong.
    var provider: MultichainSwapProvider {
        switch self {
        case .swapKit:
            return .swapKit
        case .swapsXyz, .omniston:
            return .swapXyz
        }
    }
}
