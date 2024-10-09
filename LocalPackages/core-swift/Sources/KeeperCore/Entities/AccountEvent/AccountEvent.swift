import Foundation

public struct AccountEvent: Codable {
  public typealias EventID = String
  
  public let eventId: EventID
  public let date: Date
  public let account: WalletAccount
  public let isScam: Bool
  public let isInProgress: Bool
  public let fee: Int64
  public let actions: [AccountEventAction]
  
  public init(eventId: EventID, 
              date: Date,
              account: WalletAccount,
              isScam: Bool,
              isInProgress: Bool,
              fee: Int64,
              actions: [AccountEventAction]) {
    self.eventId = eventId
    self.date = date
    self.account = account
    self.isScam = isScam
    self.isInProgress = isInProgress
    self.fee = fee
    self.actions = actions
  }
}
