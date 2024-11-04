import Foundation
import KeeperCore
import BigInt

struct BatteryRechargePayload {
  let token: Token
  let amount: BigUInt
  let promocode: String?
  
  init(token: Token, amount: BigUInt, promocode: String?) {
    self.token = token
    self.amount = amount
    self.promocode = promocode
  }
}

