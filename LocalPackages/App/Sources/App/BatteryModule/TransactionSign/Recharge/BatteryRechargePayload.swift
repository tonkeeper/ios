import Foundation
import KeeperCore
import BigInt

struct BatteryRechargePayload {
  let token: Token
  let amount: BigUInt
  
  init(token: Token, amount: BigUInt) {
    self.token = token
    self.amount = amount
  }
}

