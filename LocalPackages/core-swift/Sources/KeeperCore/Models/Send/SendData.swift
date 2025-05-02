import Foundation
import BigInt

public enum SendData {
  case ton(TonSendData)
  case tron(TronSendData)
}

public struct TonSendData {
  public enum Item {
    case token(TonToken, amount: BigUInt)
    case nft(NFT)
  }
  
  public let wallet: Wallet
  public let recipient: TonRecipient
  public let item: Item
  public let comment: String?
  
  public init(wallet: Wallet,
              recipient: TonRecipient,
              item: Item,
              comment: String?) {
    self.wallet = wallet
    self.recipient = recipient
    self.item = item
    self.comment = comment
  }
}

public struct TronSendData {
  public enum Item {
    case usdt(amount: BigUInt)
  }
  
  public let wallet: Wallet
  public let recipient: TronRecipient
  public let item: Item
  
  public init(wallet: Wallet,
              recipient: TronRecipient,
              item: Item) {
    self.wallet = wallet
    self.recipient = recipient
    self.item = item
  }
}

