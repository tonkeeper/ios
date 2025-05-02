import Foundation
import TonSwift
import BigInt

public enum Transfer {
  case ton(amount: BigUInt, recipient: TonRecipient, comment: String?)
  case jetton(JettonItem, transferAmount: BigUInt, amount: BigUInt, recipient: TonRecipient, comment: String?)
  case nft(NFT, transferAmount: BigUInt, recipient: TonRecipient, comment: String?)
  case stonfiSwap(SignRawRequest)
  case signRaw(SignRawRequest, forceRelayer: Bool)
  case renewDNS(nft: NFT)
}

