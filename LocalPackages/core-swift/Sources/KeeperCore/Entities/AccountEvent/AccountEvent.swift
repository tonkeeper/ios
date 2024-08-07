import Foundation

public struct AccountEvent: Codable {
  public let eventId: String
  public let date: Date
  public let account: WalletAccount
  public let isScam: Bool
  public let isInProgress: Bool
  public let fee: Int64
  public let actions: [AccountEventAction]
}
