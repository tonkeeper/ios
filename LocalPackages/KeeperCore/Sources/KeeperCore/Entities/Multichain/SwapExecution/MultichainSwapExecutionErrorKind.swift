public enum MultichainSwapExecutionErrorKind: Sendable, Hashable {
    case unknown
    case insufficientBalance
    case invalidAddress
    case unsupportedTransaction
    case unsupportedAsset
    case missingField
    case dustAmount
    case verificationFailed
    case signInternalError
    case unauthorized
    case noAvailableNodes
    case networkError
    case badResponse
    case providerUnavailable
    case bitcoinError
    case memPoolConflict
    case utxoError
    case internalError
}

extension MultichainSwapExecutionErrorKind: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .insufficientBalance:
            return "insufficientBalance"
        case .invalidAddress:
            return "invalidAddress"
        case .unsupportedTransaction:
            return "unsupportedTransaction"
        case .unsupportedAsset:
            return "unsupportedAsset"
        case .missingField:
            return "missingField"
        case .dustAmount:
            return "dustAmount"
        case .verificationFailed:
            return "verificationFailed"
        case .signInternalError:
            return "signInternalError"
        case .unauthorized:
            return "unauthorized"
        case .noAvailableNodes:
            return "noAvailableNodes"
        case .networkError:
            return "networkError"
        case .badResponse:
            return "badResponse"
        case .providerUnavailable:
            return "providerUnavailable"
        case .bitcoinError:
            return "bitcoinError"
        case .memPoolConflict:
            return "memPoolConflict"
        case .utxoError:
            return "utxoError"
        case .internalError:
            return "internalError"
        }
    }
}
