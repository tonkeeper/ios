import Foundation
import KeeperCore

extension InsufficientFundsError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .insufficientFunds
    }

    var message: String {
        switch self {
        case .unknownJetton:
            return "Failed to resolve jetton for balance validation"
        case .blockchainFee:
            return "Insufficient balance to cover blockchain fee"
        case .insufficientFunds:
            return "Insufficient funds"
        case .tronFee:
            return "Insufficient TRX to cover the transfer and its fee"
        }
    }

    /// Past a confirmation failure's 1–4 and a transfer error's 1–6: `send_failed` reports a shortage beside both
    /// and `swap_failed` beside the first, with no error type to tell them apart.
    var code: Int {
        switch self {
        case .unknownJetton:
            7
        case .blockchainFee:
            8
        case .insufficientFunds:
            9
        case .tronFee:
            10
        }
    }
}
