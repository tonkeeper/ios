import Foundation

public struct TransactionModel {
  public struct Item {
    public let title: String
    public let subtitle: String
    public let value: String?
    public let valueSubtitle: String?
    public let comment: String?
  }
  
  public let items: [Item]
  public let boc: String
}
