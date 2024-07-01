import Foundation
import TonSwift
import BigInt

enum TonPayloadFormat {
  case comment(String)
  case jettonTransfer(JettonTransfer)
  case nftTransfer(NftTransfer)
  
  enum PayloadType: String, Codable {
    case comment
    case jettonTransfer
    case nftTransfer
  }
  
  struct JettonTransfer {
    let queryId: BigInt?
    let coins: Coins
    let receiverAddress: Address
    let excessesAddress: Address
    let customPayload: Cell?
    let forwardAmount: Coins
    let forwardPayload: Cell?
  }
  
  struct NftTransfer {
    let queryId: BigInt?
    let newOwnerAddress: Address
    let excessesAddress: Address
    let customPayload: Cell?
    let forwardAmount: Coins
    let forwardPayload: Cell?
  }
}
