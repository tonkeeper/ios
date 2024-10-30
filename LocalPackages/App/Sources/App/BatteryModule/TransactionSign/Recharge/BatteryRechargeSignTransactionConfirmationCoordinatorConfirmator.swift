import UIKit
import KeeperCore
import TonSwift

struct BatteryRechargeSignTransactionConfirmationCoordinatorConfirmator: SignTransactionConfirmationCoordinatorConfirmator {

  private let sendService: SendService
  private let bocBuilder: BatteryRechargeBocBuilder
  
  init(bocBuilder: BatteryRechargeBocBuilder,
              sendService: SendService) {
    self.bocBuilder = bocBuilder
    self.sendService = sendService
  }
  
  func confirm(wallet: Wallet, signClosure: (TransferMessageBuilder) async throws -> String?) async throws {
    let boc = try await bocBuilder.getBoc { transferMessageBuilder in
      guard let signedBoc = try await signClosure(transferMessageBuilder) else {
        throw SignTransactionConfirmationCoordinatorConfirmatorError.failedToSign
      }
      return signedBoc
    }
    
    do {
      try await sendService.sendTransaction(boc: boc, wallet: wallet)
//      NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
    } catch {
      throw error
    }
    
//    let seqno = try await sendService.loadSeqno(wallet: wallet)
//    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
//    let amount = OP_AMOUNT.CHANGE_DNS_RECORD
//
//    let indexingLatency = try await sendService.getIndexingLatency(wallet: wallet)
//
//    if indexingLatency > (TonSwift.DEFAULT_TTL - 30) {
//      throw SignTransactionConfirmationCoordinatorConfirmatorError.indexerOffline
//    }
//
//    let boc = try await TransferMessageBuilder(
//      transferData: .changeDNSRecord(
//        .renew(
//          TransferData.ChangeDNSRecord.RenewDNS(
//            seqno: seqno,
//            nftAddress: nft.address,
//            linkAmount: amount,
//            timeout: timeout
//          )
//        )
//      )
//    ).createBoc { transferMessageBuilder in
//      guard let signedBoc = try await signClosure(transferMessageBuilder) else {
//        throw SignTransactionConfirmationCoordinatorConfirmatorError.failedToSign
//      }
//      return signedBoc
//    }
//
//    do {
//      try await sendService.sendTransaction(boc: boc, wallet: wallet)
//      NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
//    } catch {
//      throw error
//    }
  }
  
  func cancel(wallet: Wallet) async {}
}
