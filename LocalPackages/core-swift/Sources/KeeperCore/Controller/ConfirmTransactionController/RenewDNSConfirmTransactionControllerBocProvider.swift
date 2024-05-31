import Foundation
import TonSwift

public final class RenewDNSConfirmTransactionControllerBocProvider: ConfirmTransactionControllerBocProvider {
  private let nft: NFT
  private let sendService: SendService
  private let signClosure: (WalletTransfer) async throws -> Data
  
  public init(nft: NFT,
              sendService: SendService,
              signClosure: @escaping (WalletTransfer) async throws -> Data) {
    self.nft = nft
    self.sendService = sendService
    self.signClosure = signClosure
  }
  
  public func createBoc(wallet: Wallet, seqno: UInt64, timeout: UInt64) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let amount = OP_AMOUNT.CHANGE_DNS_RECORD
    
    return try await ChangeDNSRecordMessageBuilder.renewDNSMessage(
      wallet: wallet,
      seqno: seqno,
      nftAddress: nft.address,
      linkAmount: amount,
      timeout: timeout,
      signClosure: signClosure
    )
  }
}
