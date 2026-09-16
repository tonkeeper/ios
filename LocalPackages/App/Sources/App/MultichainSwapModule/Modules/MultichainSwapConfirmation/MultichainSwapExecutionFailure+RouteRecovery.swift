import KeeperCore

extension MultichainSwapExecutionFailure {
    /// A route lives for a minute, and `prepare` answers for one route id: once that id is stale
    /// the backend either rejects it or answers with payloads that cannot be used. Only a new quote
    /// clears it, so these failures ask for a fresh route instead of another pass over the old one.
    var requiresFreshRoute: Bool {
        switch self {
        case .routeExpired,
             .emptyPreparedPayloads,
             .payloadExpired,
             .payloadNotValidated,
             .missingMainPayload:
            return true
        case let .preparationFailed(kind, _):
            return kind == .internalError || kind == .badResponse || kind == .providerUnavailable
        case .canceled,
             .missingWalletAddress,
             .invalidPayload,
             .unsupportedPayloadType,
             .unsupportedAggregator,
             .insufficientNativeFee,
             .emulationFailed,
             .nonceFailed,
             .signingFailed,
             .broadcastFailed,
             .internal:
            return false
        }
    }
}
