import KeeperCore
import TKLocalize

extension MultichainSwapExecutionFailure {
    /// A relayer that did not answer may still be holding the message. Everything else fails before
    /// anything could reach a chain, or fails with the chain's own answer.
    var isBroadcastOutcomeUnknown: Bool {
        guard case .broadcastFailed = self else {
            return false
        }
        return true
    }

    var confirmationUserMessage: String? {
        switch self {
        case .canceled:
            return nil
        case .routeExpired,
             .payloadExpired,
             .emptyPreparedPayloads,
             .payloadNotValidated,
             .missingMainPayload:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.routeUnavailable
        case .insufficientNativeFee:
            return nil
        case let .emulationFailed(kind, _),
             let .preparationFailed(kind, _),
             let .nonceFailed(_, kind, _),
             let .signingFailed(_, kind, _),
             let .broadcastFailed(_, kind, _):
            return kind.confirmationUserMessage
        case .missingWalletAddress,
             .invalidPayload:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.prepareFailed
        case .unsupportedPayloadType:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.unsupportedTransaction
        case .unsupportedAggregator:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.unsupportedProvider
        case .internal:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.internalError
        }
    }
}

extension MultichainSwapExecutionErrorKind {
    var confirmationUserMessage: String {
        switch self {
        case .unknown:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.unknown
        case .insufficientBalance:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.insufficientBalance
        case .invalidAddress:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.invalidAddress
        case .unsupportedTransaction:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.unsupportedTransaction
        case .unsupportedAsset:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.unsupportedAsset
        case .missingField:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.missingField
        case .dustAmount:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.dustAmount
        case .verificationFailed:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.verificationFailed
        case .signInternalError:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.signInternalError
        case .unauthorized:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.unauthorized
        case .noAvailableNodes:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.noAvailableNodes
        case .networkError:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.networkError
        case .badResponse:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.badResponse
        case .providerUnavailable:
            return TKLocales.MultichainSwap.ProviderError.providerUnavailable
        case .bitcoinError:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.bitcoinError
        case .memPoolConflict:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.mempoolConflict
        case .utxoError:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.utxoError
        case .internalError:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.internalError
        }
    }
}
