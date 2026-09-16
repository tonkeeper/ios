import KeeperCore
import TKLocalize

extension MultichainTransactionFailure {
    var transactionConfirmationUserMessage: String {
        switch self {
        case .canceled:
            return TKLocales.Multichain.Transaction.Error.failedToPrepare
        case .unsupportedAsset:
            return TKLocales.Multichain.Transaction.Error.unsupportedAsset
        case .insufficientSelectedFee:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.insufficientBalance
        case let .emulationFailure(failure):
            return failure.transactionConfirmationUserMessage
        case let .failedToEstimateNonce(kind, _):
            return kind.transactionConfirmationUserMessage(
                fallback: TKLocales.Multichain.Transaction.Error.failedToPrepare
            )
        case let .failedToSign(kind, _):
            return kind.transactionConfirmationUserMessage(
                fallback: TKLocales.MultichainSwap.Screen.Confirm.Error.signInternalError
            )
        case let .failedToSendSigned(kind, _):
            return kind.transactionConfirmationUserMessage(
                fallback: TKLocales.Multichain.Transaction.Error.failedToSend
            )
        case .internal:
            return TKLocales.Multichain.Transaction.Error.failedToPrepare
        }
    }
}

private extension MultichainTransactionEmulationFailure {
    var transactionConfirmationUserMessage: String {
        switch self {
        case .unsupportedChain:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.unsupportedTransaction
        case .unsupportedAsset:
            return TKLocales.Multichain.Transaction.Error.unsupportedAsset
        case .invalidSenderAddress,
             .invalidRecipientAddress:
            return TKLocales.MultichainSwap.Screen.Confirm.Error.invalidAddress
        case let .chainError(kind, _):
            return kind.transactionConfirmationUserMessage(
                fallback: TKLocales.Multichain.Transaction.Error.failedToCalculateFee
            )
        case .internal:
            return TKLocales.Multichain.Transaction.Error.failedToCalculateFee
        }
    }
}

private extension MultichainSwapExecutionErrorKind {
    func transactionConfirmationUserMessage(fallback: String) -> String {
        switch self {
        case .unknown,
             .internalError:
            return fallback
        default:
            return confirmationUserMessage
        }
    }
}
