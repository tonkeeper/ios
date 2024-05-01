import Foundation
import TonSwift
import BigInt

struct TransferModel: Equatable {
  enum Transfer: Equatable {
    case tonTransfer(TonTransferModel)
    case jettonTransfer(JettonTransferModel)
    case nftTransfer(NftTransferModel)
  }
  
  struct TonTransferModel: Equatable {
    let amount: BigUInt
    let recipientAddress: Address
    let comment: String?
  }
  
  struct NftTransferModel: Equatable {
    let nftAddress: Address
    let recipientAddress: Address
    let comment: String?
  }
  
  struct JettonTransferModel: Equatable {
    let amount: BigUInt
    let jettonAddress: Address
    let recipientAddress: Address
    let comment: String?
  }
  
  let senderAddress: Address
  let transfers: [Transfer]
}
