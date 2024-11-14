import Foundation
import TonSwift
import TKBatteryAPI
import BigInt

extension BatteryBalance {
  init(balance: TKBatteryAPI.Balance) throws {
    self.balance = balance.balance
    self.reserved = balance.reserved
  }
}
