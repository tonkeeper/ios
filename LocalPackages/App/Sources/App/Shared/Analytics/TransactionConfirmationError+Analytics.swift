import KeeperCore

extension TransactionConfirmationError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .transactionSendFailed
    }

    var message: String {
        switch self {
        case .failedToCalculateFee:
            return "Failed to calculate fee"
        case .failedToSendTransaction:
            return "Failed to send transaction"
        case let .multichainTransactionFailure(failure):
            if case .emulationFailure = failure {
                return "Failed to calculate fee"
            }
            return "Multichain transaction failed"
        case .failedToSign:
            return "Failed to sign transaction"
        case .cancelledByUser:
            return "Transaction was cancelled by user"
        }
    }

    var code: Int {
        switch self {
        case .failedToCalculateFee:
            return 1
        case .failedToSendTransaction:
            return 2
        case let .multichainTransactionFailure(failure):
            if case .emulationFailure = failure {
                return 1
            }
            return 2
        case .failedToSign:
            return 3
        case .cancelledByUser:
            return 4
        }
    }
}
