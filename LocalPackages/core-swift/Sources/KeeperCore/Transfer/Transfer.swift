import Foundation
import TonSwift
import BigInt

public enum Transfer {
  case ton(amount: BigUInt, recipient: Recipient, comment: String?)
  case jetton(JettonItem, amount: BigUInt, recipient: Recipient, comment: String?)
  case nft(NFT, transferAmount: BigUInt, recipient: Recipient, comment: String?)
  case stonfiSwap(SignRawRequest)
  case signRaw(SignRawRequest, forceRelayer: Bool)
  case renewDNS(nft: NFT)
}
