import ChainKit

enum ChainKitErrorKindClassifier {
    static func kind(signError error: SignError?) -> MultichainSwapExecutionErrorKind {
        switch error {
        case is SignError.DustAmount:
            return .dustAmount
        case is SignError.InsufficientInputs:
            return .insufficientBalance
        case is SignError.InternalError:
            return .signInternalError
        case is SignError.InvalidAddress:
            return .invalidAddress
        case is SignError.MissingField:
            return .missingField
        case is SignError.UnsupportedAsset:
            return .unsupportedAsset
        case is SignError.UnsupportedTransaction:
            return .unsupportedTransaction
        case is SignError.VerificationFailed:
            return .verificationFailed
        default:
            return .unknown
        }
    }

    static func kind(nodeError error: NodeError?) -> MultichainSwapExecutionErrorKind {
        switch error {
        case is NodeError.NetworkWrap:
            return .networkError
        case is NodeError.NoAvailableNodes:
            return .noAvailableNodes
        case is NodeError.Unauthorized:
            return .unauthorized
        default:
            return .unknown
        }
    }

    static func kind(chainError error: ChainError?) -> MultichainSwapExecutionErrorKind {
        switch error {
        case is ChainError.BadResponse:
            return .badResponse
        case is ChainError.BitcoinDustError:
            return .dustAmount
        case is ChainError.BitcoinError:
            return .bitcoinError
        case is ChainError.BitcoinInsufficientInputs:
            return .insufficientBalance
        case is ChainError.BitcoinMemPoolConflict:
            return .memPoolConflict
        case is ChainError.InternalError:
            return .internalError
        case is ChainError.UtxoError:
            return .utxoError
        case let unknown as ChainError.Unknown:
            return kind(wrapped: unknown.cause)
        default:
            return .unknown
        }
    }

    /// The fee and gas paths only ever surface `ChainError`, so a node-level failure — a rejected
    /// device JWT, an empty node manifest, a dropped connection — arrives as `ChainError.Unknown`
    /// around the real error. `kind` is the only part of a failure that reaches the logs, so
    /// without unwrapping every one of those is indistinguishable from a genuine chain error.
    private static func kind(wrapped error: KotlinThrowable?) -> MultichainSwapExecutionErrorKind {
        switch error {
        case let error as NodeError:
            return kind(nodeError: error)
        case let error as SignError:
            return kind(signError: error)
        case let error as ChainError:
            return kind(chainError: error)
        default:
            return .unknown
        }
    }
}
