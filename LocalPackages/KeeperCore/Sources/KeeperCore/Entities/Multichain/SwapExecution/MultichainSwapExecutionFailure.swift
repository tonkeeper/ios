import TKLogging

public enum MultichainSwapExecutionFailure: Error, Sendable, Hashable {
    case canceled
    case routeExpired(routeId: String)
    case emptyPreparedPayloads(routeId: String)
    case payloadExpired(payloadId: String)
    case payloadNotValidated(payloadId: String, status: String)
    case missingWalletAddress(chain: MultichainChain)
    case invalidPayload(payloadId: String, reason: String)
    case unsupportedPayloadType(String)
    case unsupportedAggregator(String)
    case insufficientNativeFee(shortage: MultichainNativeFeeShortage)
    case preparationFailed(kind: MultichainSwapExecutionErrorKind, reason: String)
    case emulationFailed(kind: MultichainSwapExecutionErrorKind, reason: String)
    case nonceFailed(payloadId: String, kind: MultichainSwapExecutionErrorKind, reason: String)
    case signingFailed(payloadId: String, kind: MultichainSwapExecutionErrorKind, reason: String)
    case broadcastFailed(payloadId: String, kind: MultichainSwapExecutionErrorKind, reason: String)
    case missingMainPayload(routeId: String)
    case `internal`(reason: String)
}

extension MultichainSwapExecutionFailure: LoggableError {
    public var logDescription: String {
        switch self {
        case .canceled:
            return "type=MultichainSwapExecutionFailure, case=canceled"
        case let .routeExpired(routeId):
            return "type=MultichainSwapExecutionFailure, case=routeExpired, routeId=\(routeId)"
        case let .emptyPreparedPayloads(routeId):
            return "type=MultichainSwapExecutionFailure, case=emptyPreparedPayloads, routeId=\(routeId)"
        case let .payloadExpired(payloadId):
            return "type=MultichainSwapExecutionFailure, case=payloadExpired, payloadId=\(payloadId)"
        case let .payloadNotValidated(payloadId, status):
            return "type=MultichainSwapExecutionFailure, case=payloadNotValidated, payloadId=\(payloadId), status=\(status)"
        case let .missingWalletAddress(chain):
            return "type=MultichainSwapExecutionFailure, case=missingWalletAddress, chain=\(chain.rawValue)"
        case let .invalidPayload(payloadId, _):
            return "type=MultichainSwapExecutionFailure, case=invalidPayload, payloadId=\(payloadId)"
        case let .unsupportedPayloadType(type):
            return "type=MultichainSwapExecutionFailure, case=unsupportedPayloadType, payloadType=\(type)"
        case let .unsupportedAggregator(aggregator):
            return "type=MultichainSwapExecutionFailure, case=unsupportedAggregator, aggregator=\(aggregator)"
        case let .insufficientNativeFee(shortage):
            return "type=MultichainSwapExecutionFailure, case=insufficientNativeFee, assetId=\(shortage.asset.assetId)"
        case let .preparationFailed(kind, _):
            return "type=MultichainSwapExecutionFailure, case=preparationFailed, kind=\(kind.description)"
        case let .emulationFailed(kind, _):
            return "type=MultichainSwapExecutionFailure, case=emulationFailed, kind=\(kind.description)"
        case let .nonceFailed(payloadId, kind, _):
            return "type=MultichainSwapExecutionFailure, case=nonceFailed, payloadId=\(payloadId), kind=\(kind.description)"
        case let .signingFailed(payloadId, kind, _):
            return "type=MultichainSwapExecutionFailure, case=signingFailed, payloadId=\(payloadId), kind=\(kind.description)"
        case let .broadcastFailed(payloadId, kind, _):
            return "type=MultichainSwapExecutionFailure, case=broadcastFailed, payloadId=\(payloadId), kind=\(kind.description)"
        case let .missingMainPayload(routeId):
            return "type=MultichainSwapExecutionFailure, case=missingMainPayload, routeId=\(routeId)"
        case .internal:
            return "type=MultichainSwapExecutionFailure, case=internal"
        }
    }
}
