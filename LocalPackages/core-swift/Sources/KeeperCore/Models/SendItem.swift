import Foundation
import BigInt

public enum SendItem {
  case token(TonToken, amount: BigUInt)
  case nft(NFT)
}
