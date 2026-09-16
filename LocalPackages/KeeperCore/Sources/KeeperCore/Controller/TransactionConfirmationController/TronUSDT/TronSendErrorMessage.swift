import TKLocalize
import TronSwiftAPI

/// Keeps the node's own wording — and the `NSError` fallback it degrades into — out of the UI:
/// the user gets a localized message, the technical detail goes to the log.
enum TronSendErrorMessage {
    static func userMessage(for error: Swift.Error) -> String {
        if let tronError = error as? TronApi.Error, tronError.isInsufficientTronResources {
            return TKLocales.TronUsdtFees.InsufficientPopup.title
        }
        return TKLocales.Multichain.Transaction.Error.failedToSend
    }

    static func logDescription(for error: Swift.Error) -> String {
        guard let tronError = error as? TronApi.Error else {
            return "\(error)"
        }
        switch tronError {
        case let .transactionRejected(code, message):
            return "rejected \(code): \(message ?? "no message")"
        case let .serverError(statusCode):
            return "server error \(statusCode)"
        case let .apiError(message):
            return "api error: \(message)"
        case let .invalidHex(reason):
            return "invalid hex: \(reason)"
        default:
            return "\(tronError)"
        }
    }
}
