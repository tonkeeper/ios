import TKLogging

public enum MultichainTransactionFailure: Error {
    case canceled
    case unsupportedAsset(id: String)
    case insufficientSelectedFee
    case emulationFailure(MultichainTransactionEmulationFailure)
    case failedToEstimateNonce(kind: MultichainSwapExecutionErrorKind, reason: String)
    case failedToSign(kind: MultichainSwapExecutionErrorKind, reason: String)
    case failedToSendSigned(kind: MultichainSwapExecutionErrorKind, reason: String)
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
        case .internal:
            return "type=MultichainTransactionFailure, case=internal"
        }
    }
}
