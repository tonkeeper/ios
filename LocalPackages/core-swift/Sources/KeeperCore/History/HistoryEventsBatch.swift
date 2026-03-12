import Foundation

public struct HistoryEventsBatch: Sendable {
    public let accountsEvents: AccountEvents?
    public let tronTransactions: [TronTransaction]
}
