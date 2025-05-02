import Foundation

public struct HistoryEventsBatch {
  public let accountsEvents: AccountEvents?
  public let tronTransactions: [TronTransaction]
}
