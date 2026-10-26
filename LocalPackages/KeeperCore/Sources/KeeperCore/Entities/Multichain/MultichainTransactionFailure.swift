import TKLogging

@frozen public enum MultichainTransactionFailure: Error {
    case canceled
    case unsupportedAsset(id: String)
    case insufficientSelectedFee
    case emulationFailure(MultichainTransactionEmulationFailure)
    case failedToEstimateNonce(kind: MultichainSwapExecutionErrorKind, reason: String)
    case failedToSign(kind: MultichainSwapExecutionErrorKind, reason: String)
    case failedToSendSigned(kind: MultichainSwapExecutionErrorKind, reason: String)
    /// The relayer could not price the chosen fee method when the transfer was about to go out.
    case relayerQuoteUnavailable(reason: String)
    /// The relayer no longer holds the emulated operation the signatures answer.
    case relayerQuoteExpired
    /// The relayer refused to broadcast the signed operation.
    case relayerRejected(reason: String)
    /// The relayer may have broadcast the signed operation: it did not answer, or says it already has.
    case relayerOutcomeUnknown(reason: String)
    case `internal`(reason: String)
}

extension MultichainTransactionFailure: LoggableError {
    public var logDescription: String {
        switch self {
        case .canceled:
            return "type=MultichainTransactionFailure, case=canceled"
        case let .unsupportedAsset(id):
            return "type=MultichainTransactionFailure, case=unsupportedAsset, assetId=\(id)"
        case .insufficientSelectedFee:
            return "type=MultichainTransactionFailure, case=insufficientSelectedFee"
        case let .emulationFailure(failure):
            return "type=MultichainTransactionFailure, case=emulationFailure, underlying=\(failure.logDescription)"
        case let .failedToEstimateNonce(kind, _):
            return "type=MultichainTransactionFailure, case=failedToEstimateNonce, kind=\(kind.description)"
        case let .failedToSign(kind, _):
            return "type=MultichainTransactionFailure, case=failedToSign, kind=\(kind.description)"
        case let .failedToSendSigned(kind, _):
            return "type=MultichainTransactionFailure, case=failedToSendSigned, kind=\(kind.description)"
        case let .relayerQuoteUnavailable(reason):
            return "type=MultichainTransactionFailure, case=relayerQuoteUnavailable, reason=\(reason)"
        case .relayerQuoteExpired:
            return "type=MultichainTransactionFailure, case=relayerQuoteExpired"
        case let .relayerRejected(reason):
            return "type=MultichainTransactionFailure, case=relayerRejected, reason=\(reason)"
        case let .relayerOutcomeUnknown(reason):
            return "type=MultichainTransactionFailure, case=relayerOutcomeUnknown, reason=\(reason)"
        case .internal:
            return "type=MultichainTransactionFailure, case=internal"
        }
    }
}
