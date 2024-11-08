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
  
  func confirm(wallet: Wallet, signClosure: (TransferData) async throws -> String?) async throws {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let amount = OP_AMOUNT.CHANGE_DNS_RECORD
    
    let indexingLatency = try await sendService.getIndexingLatency(wallet: wallet)
    
    if indexingLatency > (TonSwift.DEFAULT_TTL - 30) {
      throw SignTransactionConfirmationCoordinatorConfirmatorError.indexerOffline
    }
    
    let transferData = TransferData(
      transfer: .changeDNSRecord(
        TransferData.ChangeDNSRecord.renew(
          TransferData.ChangeDNSRecord.RenewDNS(
            nftAddress: nft.address,
            linkAmount: amount
          )
        )
      ),
      wallet: wallet,
      messageType: .ext,
      seqno: seqno,
      timeout: timeout
    )
        
    guard let signedBoc = try await signClosure(transferData) else {
      throw SignTransactionConfirmationCoordinatorConfirmatorError.failedToSign
    }
    
    do {
      try await sendService.sendTransaction(boc: signedBoc, wallet: wallet)
      NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
    } catch {
      throw error
    }
  }
  
  func cancel(wallet: Wallet) async {}
}
