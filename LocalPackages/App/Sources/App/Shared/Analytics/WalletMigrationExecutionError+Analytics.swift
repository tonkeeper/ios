import KeeperCore

extension WalletMigrationExecutionError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        switch self {
        case .unsupportedWalletKind:
            return .incorrectWalletKind
        case .signingFailed:
            return .signFailed
        case .insufficientTronFee:
            return .insufficientFunds
        case .inactiveTronAccount:
            return .transactionSendFailed
        case .emptyTransactions, .sendFailed, .partiallySent, .tronAddressUnavailable:
            return .transactionSendFailed
        }
    }

    var message: String {
        switch self {
        case .emptyTransactions:
            return "Nothing to migrate"
        case .unsupportedWalletKind:
            return "Unsupported wallet kind"
        case .signingFailed:
            return "Failed to sign migration transaction"
        case let .sendFailed(message):
            return message
        case let .partiallySent(message):
            return message
        case .tronAddressUnavailable:
            return "TRON address unavailable"
        case .insufficientTronFee:
            return "Insufficient TRON fee"
        case .inactiveTronAccount:
            return "TRON account is not activated"
        }
    }

    var code: Int {
        switch self {
        case .emptyTransactions:
            1
        case .unsupportedWalletKind:
            2
        case .signingFailed:
            3
        case .sendFailed:
            4
        case .partiallySent:
            9
        case .tronAddressUnavailable:
            5
        case .insufficientTronFee:
            7
        case .inactiveTronAccount:
            8
        }
    }
}
