import Foundation
import TonSwift

public final class RenewDNSConfirmTransactionControllerBocProvider: ConfirmTransactionControllerBocProvider {
  private let nft: NFT
  private let sendService: SendService
  
  public init(nft: NFT,
              sendService: SendService) {
    self.nft = nft
    self.sendService = sendService
  }
  
  public func createBoc(wallet: Wallet, seqno: UInt64, timeout: UInt64) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let amount = OP_AMOUNT.CHANGE_DNS_RECORD
    
    let transferData = TransferData(
      transfer: .changeDNSRecord(
        .renew(
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
    let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
      .createUnsignedWalletTransfer(
        wallet: wallet
      )
    
    let signed = try TransferSigner.signWalletTransfer(
      walletTransfer,
      wallet: wallet,
      seqno: transferData.seqno,
      signer: WalletTransferEmptyKeySigner()
    ).toBoc().hexString()
    
    return signed
  }
}
