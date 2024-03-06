import Foundation
import BigInt
import KeeperCore

struct SendModel {
  let wallet: Wallet
  let recipient: Recipient?
  let sendItem: SendItem
  let comment: String?
  
  init(wallet: Wallet,
       recipient: Recipient?,
       sendItem: SendItem,
       comment: String?) {
    self.wallet = wallet
    self.recipient = recipient
    self.sendItem = sendItem
    self.comment = comment
  }
}


