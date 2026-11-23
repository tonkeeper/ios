import TKLocalize
import TKLogging

extension TransactionConfirmationError {
    /// A transfer the wallet could not build reads apart from one the network refused, and a signing
    /// failure keeps its own case instead of passing for a send failure.
    init(sendFailure: SomeOf<TransferError, TransactionConfirmationError>) {
        switch sendFailure {
        case let .firstOption(transferError):
            self.init(transferFailure: transferError)
        case let .secondOption(error):
            self = error
        }
    }

    /// A relayer that refused for lack of funds names the one cause the user can act on, so the user reads it
    /// instead of the generic text.
    public init(transferFailure: TransferError) {
        switch transferFailure {
        case let .sendFailed(message, refusal):
            self = .failedToSendTransaction(
                message: message,
                localizedMessage: refusal?.isFundsShortage == true ? TKLocales.TronUsdtFees.InsufficientPopup.title : nil
            )
        default:
            self = .failedToSendTransaction(message: "failed to prepare transaction: \(transferFailure.analyticsReason)")
        }
    }
}
