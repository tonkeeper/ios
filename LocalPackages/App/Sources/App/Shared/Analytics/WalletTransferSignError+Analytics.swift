import Foundation

extension WalletTransferSignError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .walletTransferFailed
    }

    var message: String {
        switch self {
        case .incorrectWalletKind:
            return "Unsupported wallet kind for transaction signing"
        case .cancelled:
            return "Transaction signing was cancelled"
        case let .failedToSign(message):
            return "Failed to sign transaction due to error: \(message ?? "unknown")"
        }
    }

    var code: Int {
        switch self {
        case .failedToSign:
            return 1
        case .incorrectWalletKind:
            return 2
        case .cancelled:
            return 3
        }
    }
}
