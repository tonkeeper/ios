import Foundation
import TonSwift
import BigInt

public enum TonPayloadFormat {
  case comment(String)
  case jettonTransfer(JettonTransfer)
  case nftTransfer(NftTransfer)
  
  public enum PayloadType: String, Codable {
    case comment
    case jettonTransfer
    case nftTransfer
  }
  
  public struct JettonTransfer {
    let queryId: BigUInt?
    let coins: Coins
    let receiverAddress: Address
    let excessesAddress: Address
    let customPayload: Cell?
    let forwardAmount: Coins
    let forwardPayload: Cell?
    
    public init(queryId: BigUInt?, coins: Coins, receiverAddress: Address, excessesAddress: Address, customPayload: Cell?, forwardAmount: Coins, forwardPayload: Cell?) {
      self.queryId = queryId
      self.coins = coins
      self.receiverAddress = receiverAddress
      self.excessesAddress = excessesAddress
      self.customPayload = customPayload
      self.forwardAmount = forwardAmount
      self.forwardPayload = forwardPayload
    }
  }
  
  public struct NftTransfer {
    let queryId: BigUInt?
    let newOwnerAddress: Address
    let excessesAddress: Address
    let customPayload: Cell?
    let forwardAmount: Coins
    let forwardPayload: Cell?
    
    public init(queryId: BigUInt?, newOwnerAddress: Address, excessesAddress: Address, customPayload: Cell?, forwardAmount: Coins, forwardPayload: Cell?) {
      self.queryId = queryId
      self.newOwnerAddress = newOwnerAddress
      self.excessesAddress = excessesAddress
      self.customPayload = customPayload
      self.forwardAmount = forwardAmount
      self.forwardPayload = forwardPayload
    }
  }
}
