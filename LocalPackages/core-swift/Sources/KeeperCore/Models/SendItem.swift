import BigInt
import Foundation

public enum SendItem {
    case token(TonToken, amount: BigUInt)
    case nft(NFT)
}
