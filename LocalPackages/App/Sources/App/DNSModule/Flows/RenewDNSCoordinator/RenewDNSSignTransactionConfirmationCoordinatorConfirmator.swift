import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKCore
import TonSwift

struct RenewDNSSignTransactionConfirmationCoordinatorConfirmator: SignTransactionConfirmationCoordinatorConfirmator {

  private let nft: NFT
  private let sendService: SendService
  
  init(nft: NFT, 
       sendService: SendService) {
    self.nft = nft
    self.sendService = sendService
  }
  
  func confirm(wallet: Wallet, signClosure: (TransferMessageBuilder) async throws -> String?) async throws {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let amount = OP_AMOUNT.CHANGE_DNS_RECORD
    
    let indexingLatency = try await sendService.getIndexingLatency(wallet: wallet)
    
    if indexingLatency > (TonSwift.DEFAULT_TTL - 30) {
      throw SignTransactionConfirmationCoordinatorConfirmatorError.indexerOffline
    }
    
    let boc = try await TransferMessageBuilder(
      transferData: .changeDNSRecord(
        .renew(
          TransferData.ChangeDNSRecord.RenewDNS(
            seqno: seqno,
            nftAddress: nft.address,
            linkAmount: amount,
            timeout: timeout
          )
        )
      )
    ).createBoc { transferMessageBuilder in
      guard let signedBoc = try await signClosure(transferMessageBuilder) else {
        throw SignTransactionConfirmationCoordinatorConfirmatorError.failedToSign
      }
      return signedBoc
    }

    try await sendService.sendTransaction(boc: boc, wallet: wallet)
  }
  
  func cancel(wallet: Wallet) async {}
}
