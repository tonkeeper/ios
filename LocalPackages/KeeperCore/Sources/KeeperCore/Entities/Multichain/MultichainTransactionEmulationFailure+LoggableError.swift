import TKLogging

extension MultichainTransactionEmulationFailure: LoggableError {
    public var logDescription: String {
        switch self {
        case let .unsupportedChain(chain):
            return "type=MultichainTransactionEmulationFailure, case=unsupportedChain, chain=\(chain.rawValue)"
        case let .unsupportedAsset(id):
            return "type=MultichainTransactionEmulationFailure, case=unsupportedAsset, assetId=\(id)"
        case .invalidSenderAddress:
            return "type=MultichainTransactionEmulationFailure, case=invalidSenderAddress"
        case .invalidRecipientAddress:
            return "type=MultichainTransactionEmulationFailure, case=invalidRecipientAddress"
        // The reason of a chain error is composed from ChainKit type names only, so unlike the
        // address-carrying cases it is safe to log — and it is the only place the concrete
        // ChainKit error behind an unclassified `kind` survives.
        case let .chainError(kind, reason):
            return "type=MultichainTransactionEmulationFailure, case=chainError, kind=\(kind.description), reason=\(reason)"
        case .internal:
            return "type=MultichainTransactionEmulationFailure, case=internal"
        }
    }
}
