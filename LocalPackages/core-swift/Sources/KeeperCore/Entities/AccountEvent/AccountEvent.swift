import Foundation

public struct AccountEvent: Codable {
  public typealias EventID = String
  
  public enum Extra: Codable {
    case Fee(UInt64)
    case Refund(UInt64)
  }
  
  public let eventId: EventID
  public let date: Date
  public let account: WalletAccount
  public let isScam: Bool
  public let isInProgress: Bool
  public let extra: Extra
  public let actions: [AccountEventAction]
  
  public init(eventId: EventID, 
              date: Date,
              account: WalletAccount,
              isScam: Bool,
              isInProgress: Bool,
              extra: Extra,
              actions: [AccountEventAction]) {
    self.eventId = eventId
    self.date = date
    self.account = account
    self.isScam = isScam
    self.isInProgress = isInProgress
    self.extra = extra
    self.actions = actions
  }
}
