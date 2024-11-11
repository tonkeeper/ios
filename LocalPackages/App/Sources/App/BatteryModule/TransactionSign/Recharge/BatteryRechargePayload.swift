import Foundation
import KeeperCore
import BigInt

struct BatteryRechargePayload {
  let token: Token
  let amount: BigUInt
  let promocode: String?
  let recipient: Recipient?
  
  init(token: Token,
       amount: BigUInt,
       promocode: String?,
       recipient: Recipient?) {
    self.token = token
    self.amount = amount
    self.promocode = promocode
    self.recipient = recipient
  }
}

