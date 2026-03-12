import Foundation
import KeeperCore

enum SendAnalyticsErrorMapper {
    static func errorCode(from error: Error) -> Int {
        if let confirmationError = error as? TransactionConfirmationError {
            switch confirmationError {
            case .failedToCalculateFee:
                return 1
            case .failedToSendTransaction:
                return 2
            case .failedToSign:
                return 3
            }
        }

        if error.isNoConnectionError {
            return 101
        }

        if error is InsufficientFundsError {
            return 100
        }

        return (error as NSError).code
    }

    static func errorMessage(from error: Error) -> String {
        let message = error.localizedDescription
        if message.isEmpty {
            return String(describing: error)
        }
        return message
    }
}
