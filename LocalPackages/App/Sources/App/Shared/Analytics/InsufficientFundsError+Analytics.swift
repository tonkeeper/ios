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

    var code: Int {
        switch self {
        case .unknownJetton:
            1
        case .blockchainFee:
            2
        case .insufficientFunds:
            3
        case .tronFee:
            4
        }
    }
}
