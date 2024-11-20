import Foundation
import KeeperCore
import BigInt

struct TransactionConfirmationDeeplinkPayload {
  let amount: BigUInt
  let recipient: Recipient
  let payload: String?
  let stateInit: String?
  
  init(amount: BigUInt,
       recipient: Recipient,
       payload: String?,
       stateInit: String?) {
    self.amount = amount
    self.recipient = recipient
    self.payload = payload
    self.stateInit = stateInit
  }
}

