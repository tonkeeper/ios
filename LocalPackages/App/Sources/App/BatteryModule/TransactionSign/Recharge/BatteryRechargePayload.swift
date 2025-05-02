import Foundation
import KeeperCore
import BigInt

struct BatteryRechargePayload {
  let token: TonToken
  let amount: BigUInt
  let promocode: String?
  let recipient: TonRecipient?
  
  init(token: TonToken,
       amount: BigUInt,
       promocode: String?,
       recipient: TonRecipient?) {
    self.token = token
    self.amount = amount
    self.promocode = promocode
    self.recipient = recipient
  }
}

