import Foundation

extension SignDataSignError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .signFailed
    }

    var message: String {
        switch self {
        case .incorrectWalletKind:
            return "Unsupported wallet kind for sign data"
        case .cancelled:
            return "Sign data was cancelled"
        case let .failedToSign(message):
            return "Failed to sign data due to error: \(message ?? "unknown")"
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
