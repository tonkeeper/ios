import Foundation
import BigInt
import KeeperCore

struct SendTokenModel {
  let wallet: Wallet
  let recipient: Recipient?
  let amount: BigUInt
  let token: Token
  let comment: String?
  
  init(wallet: Wallet,
       recipient: Recipient?,
       amount: BigUInt,
       token: Token,
       comment: String?) {
    self.wallet = wallet
    self.recipient = recipient
    self.amount = amount
    self.token = token
    self.comment = comment
  }
}


