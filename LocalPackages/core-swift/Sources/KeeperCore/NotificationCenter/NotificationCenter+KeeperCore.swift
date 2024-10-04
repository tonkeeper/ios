import Foundation

public extension NotificationCenter {
  func postTransactionSendNotification(wallet: Wallet) {
    self.post(.transactionSendNotification(wallet: wallet))
  }
}

public extension Notification {
  static func transactionSendNotification(wallet: Wallet) -> Notification {
    let userInfo = ["wallet": wallet]
    return Notification(name: .transactionSendNotification, object: nil, userInfo: userInfo)
  }
}

public extension Notification.Name {
  static var transactionSendNotification = Notification.Name("TransactionSendNotification")
}

