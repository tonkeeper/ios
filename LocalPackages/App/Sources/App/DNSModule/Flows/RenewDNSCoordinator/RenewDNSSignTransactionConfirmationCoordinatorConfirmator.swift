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
  
  func confirm(wallet: Wallet, signClosure: (WalletTransfer) async throws -> Data?) async throws {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let amount = OP_AMOUNT.CHANGE_DNS_RECORD
    
    let boc = try await ChangeDNSRecordMessageBuilder.renewDNSMessage(
      wallet: wallet,
      seqno: seqno,
      nftAddress: nft.address,
      linkAmount: amount,
      timeout: timeout,
      signClosure: { walletTranfer in
        guard let signedData = try await signClosure(walletTranfer) else {
          throw SignTransactionConfirmationCoordinatorConfirmatorError.failedToSign
        }
        return signedData
      }
    )
    
    try await sendService.sendTransaction(boc: boc, wallet: wallet)
  }
  
  func cancel(wallet: Wallet) async {}
}
