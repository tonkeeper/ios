import KeeperCore
import TKLocalize

extension TransactionConfirmationError {
    /// What a failed confirmation tells the user: a localized text, never the reason analytics reads. `nil` for
    /// a cancel, which needs no toast.
    var userMessage: String? {
        switch self {
        case .failedToCalculateFee:
            TKLocales.Multichain.Transaction.Error.failedToCalculateFee
        case let .failedToSendTransaction(_, localizedMessage):
            localizedMessage ?? TKLocales.Multichain.Transaction.Error.failedToSend
        case let .multichainTransactionFailure(failure):
            failure.transactionConfirmationUserMessage
        case .failedToSign:
            TKLocales.MultichainSwap.Screen.Confirm.Error.signInternalError
        case .cancelledByUser:
            nil
        }
    }
}
