import Foundation
import TonSwift
import TonAPI

extension Account {
  init(account: TonAPI.Account) throws {
    self.address = try Address.parse(account.address)
    self.balance = account.balance
    self.status = account.status.rawValue
    self.name = account.name
    self.icon = account.icon
    self.isSuspended = account.isSuspended
    self.isWallet = account.isWallet
  }
}
