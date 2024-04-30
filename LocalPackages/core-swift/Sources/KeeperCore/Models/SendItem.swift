import Foundation
import BigInt

public enum SendItem {
  case token(Token, amount: BigUInt)
  case nft(NFT)
}
