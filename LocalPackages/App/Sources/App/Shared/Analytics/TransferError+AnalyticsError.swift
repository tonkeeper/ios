import KeeperCore

extension TransferError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .transferFailed
    }

    /// The text the transfers and the swap report for the same failure.
    var message: String {
        TransactionConfirmationError(transferFailure: self).message
    }

    var code: Int {
        switch self {
        case .nothingToSend:
            1
        case .unsupportedTransfer:
            2
        case .failedToCreateTransferData:
            3
        case .noExcessesAddress:
            4
        case .noJettonWalletAddress:
            5
        case .sendFailed:
            6
        }
    }
}
