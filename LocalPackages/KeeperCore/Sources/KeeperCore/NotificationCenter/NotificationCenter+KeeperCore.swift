import Foundation

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
}

public extension Notification {
    /// Set when the sent asset has no feed in this wallet, leaving a history screen nothing to show.
    static let transactionSendWithoutHistoryKey = "transactionSendWithoutHistory"
}
