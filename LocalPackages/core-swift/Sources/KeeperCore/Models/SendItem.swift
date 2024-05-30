import Foundation
import BigInt
import TonSwift

public enum SendItem {
  public enum SwapType {
    case jettonJetton(from: Address, to: Address, minAskAmount: BigUInt, offerAmount: BigUInt)
    case tonJetton(to: Address, minAskAmount: BigUInt, offerAmount: BigUInt)
    case jettonTon(from: Address, minAskAmount: BigUInt, offerAmount: BigUInt)
  }
  case token(Token, amount: BigUInt)
  case nft(NFT)
  case swap(SwapType)
  case staking(pool: PoolInfo, token: Address, amount: BigUInt)
}
