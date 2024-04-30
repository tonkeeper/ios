import Foundation

public struct AccountEventDetailsEvent {
  public let accountEvent: AccountEvent
  public let action: AccountEventAction
  
  public init(accountEvent: AccountEvent, action: AccountEventAction) {
    self.accountEvent = accountEvent
    self.action = action
  }
}

