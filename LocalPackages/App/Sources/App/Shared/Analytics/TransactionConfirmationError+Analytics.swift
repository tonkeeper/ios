import KeeperCore

extension TransactionConfirmationError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        switch self {
        case .failedToCalculateFee:
            return .feeCalculationFailed
        case let .multichainTransactionFailure(failure):
            return failure.isFeeCalculationIssue ? .feeCalculationFailed : .transactionSendFailed
        case .failedToSendTransaction, .failedToSign, .cancelledByUser:
            return .transactionSendFailed
        }
    }

    var message: String {
        switch self {
        case let .failedToCalculateFee(message):
            return message ?? "Failed to calculate fee"
        case let .failedToSendTransaction(message, _):
            return message ?? "Failed to send transaction"
        case let .multichainTransactionFailure(failure):
            return failure.analyticsReason
        case let .failedToSign(message):
            return message ?? "Failed to sign transaction"
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
            return failure.isFeeCalculationIssue ? 1 : 2
        case .failedToSign:
            return 3
        case .cancelledByUser:
            return 4
        }
    }
}

private extension MultichainTransactionFailure {
    var isFeeCalculationIssue: Bool {
        switch self {
        case .emulationFailure, .feeQuoteLoading, .feeMethodUnavailable:
            return true
        case .canceled, .unsupportedAsset, .insufficientSelectedFee, .batteryMigrationFailed,
             .operationExpired, .failedToEstimateNonce, .failedToSign, .failedToSendSigned,
             .relayerQuoteUnavailable, .relayerQuoteExpired, .relayerRejected, .relayerOutcomeUnknown, .internal:
            return false
        }
    }
}

extension AnalyticsError {
    var transactionConfirmationStage: String {
        type == .feeCalculationFailed ? "fee" : "send"
    }
}
