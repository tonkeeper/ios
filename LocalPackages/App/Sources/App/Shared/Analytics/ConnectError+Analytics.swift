import Foundation

extension ConnectError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .connection
    }

    var message: String {
        switch self {
        case .unknown:
            "Failed to connect wallet"
        case .cancelled:
            "Wallet connection was cancelled"
        case .noPasscode:
            "Passcode is not set"
        }
    }

    var code: Int {
        switch self {
        case .unknown:
            1
        case .cancelled:
            2
        case .noPasscode:
            3
        }
    }
}
