import KeeperCore

extension WalletMigrationError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        switch self {
        case .insufficientTonForGas, .insufficientTrxForFees:
            .insufficientFunds
        case .inactiveTronAccount:
            .transactionSendFailed
        }
    }

    var message: String {
        switch self {
        case .insufficientTonForGas:
            return "Insufficient TON to cover migration gas"
        case .insufficientTrxForFees:
            return "Insufficient TRX to cover migration fees"
        case .inactiveTronAccount:
            return "TRON account is not activated"
        }
    }

    var code: Int {
        switch self {
        case .insufficientTonForGas:
            1
        case .insufficientTrxForFees:
            2
        case .inactiveTronAccount:
            3
        }
    }
}
