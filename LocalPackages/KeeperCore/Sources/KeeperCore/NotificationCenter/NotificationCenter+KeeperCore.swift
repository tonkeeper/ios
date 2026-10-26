import Foundation
import PerpsModels

public extension NotificationCenter {
    func postTransactionSendNotification(
        wallet: Wallet?,
        patch: @escaping (inout [String: Any]) -> Void = { _ in }
    ) {
        self.post(.transactionSendNotification(
            wallet: wallet,
            patch: patch
        ))
    }
}

public extension Notification {
    static func transactionSendNotification(
        wallet: Wallet?,
        patch: @escaping (inout [String: Any]) -> Void = { _ in }
    ) -> Notification {
        var userInfo = [String: Any]()
        if let wallet {
            userInfo["wallet"] = wallet
        }
        patch(&userInfo)
        return Notification(name: .transactionSendNotification, object: nil, userInfo: userInfo)
    }
}

public extension Notification.Name {
    static var transactionSendNotification = Notification.Name("TransactionSendNotification")
    static let multichainTransactionBroadcast = Notification.Name("MultichainTransactionBroadcast")
    /// Object: `PerpsTradingSettlement`.
    static let perpsTradingOperationSettled = Notification.Name("PerpsTradingOperationSettled")
}

public struct PerpsTradingSettlement: Sendable {
    public let action: PerpsPendingTradingAction
    public let succeeded: Bool

    public init(action: PerpsPendingTradingAction, succeeded: Bool) {
        self.action = action
        self.succeeded = succeeded
    }
}

public extension Notification {
    /// Set when the main coordinator must not open history on the notification: the sent asset
    /// has no feed in this wallet, leaving a history screen nothing to show, or the sending flow
    /// opens history itself.
    static let transactionSendWithoutHistoryKey = "transactionSendWithoutHistory"
}
