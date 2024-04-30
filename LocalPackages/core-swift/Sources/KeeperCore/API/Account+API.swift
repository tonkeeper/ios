import Foundation
import TonSwift
import TonAPI

extension Account {
  init(account: Components.Schemas.Account) throws {
    self.address = try Address.parse(account.address)
    self.balance = account.balance
    self.status = account.status
    self.name = account.name
    self.icon = account.icon
    self.isSuspended = account.is_suspended
    self.isWallet = account.is_wallet
  }
}
