import Foundation
import TonSwift
import BigInt

public final class LinkDNSController {
  public enum Error: Swift.Error {
    case failedToSign
    case indexerOffline
  }
  
  private let wallet: Wallet
  private let nft: NFT
  private let sendService: SendService
  
  init(wallet: Wallet, 
       nft: NFT,
       sendService: SendService) {
    self.wallet = wallet
    self.nft = nft
    self.sendService = sendService
  }
  
  public func emulate(dnsLink: DNSLink) async throws -> SendTransactionModel {
    let boc = try await createBoc(dnsLink: dnsLink) { transferData in
      let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
        .createUnsignedWalletTransfer(
          wallet: wallet
        )
      let signed = try TransferSigner.signWalletTransfer(
        walletTransfer,
        wallet: wallet,
        seqno: transferData.seqno,
        signer: WalletTransferEmptyKeySigner()
      )
      
      return try signed.toBoc().hexString()
    }
    
    let transactionInfo = try await sendService.loadTransactionInfo(
      boc: boc,
      wallet: wallet
    )
    
    return try SendTransactionModel(
      accountEvent: transactionInfo.event,
      risk: transactionInfo.risk,
      transaction: transactionInfo.trace.transaction
    )
  }

  public func sendLinkTransaction(dnsLink: DNSLink,
                                  signClosure: (TransferData) async throws -> String?) async throws {
    let indexingLatency = try await sendService.getIndexingLatency(wallet: wallet)
    if indexingLatency > (TonSwift.DEFAULT_TTL - 30) {
      throw Error.indexerOffline
    }
    
    let boc = try await createBoc(dnsLink: dnsLink) { transferData in
      guard let boc = try await signClosure(transferData) else {
        throw Error.failedToSign
      }
      return boc
    }
    do {
      try await sendService.sendTransaction(boc: boc, wallet: wallet)
      NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
    } catch {
      throw error
    }
  }
}

private extension LinkDNSController {
  func createBoc(dnsLink: DNSLink, signClosure: (TransferData) async throws -> String) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let linkAmount = OP_AMOUNT.CHANGE_DNS_RECORD
    let linkAddress: Address?
    switch dnsLink {
    case .link(let address):
      linkAddress = address.address
    case .unlink:
      linkAddress = nil
    }
    
    let transferData = TransferData(
      transfer: .changeDNSRecord(TransferData.ChangeDNSRecord.link(TransferData.ChangeDNSRecord.LinkDNS(nftAddress: nft.address, linkAddress: linkAddress, linkAmount: linkAmount))),
      wallet: wallet,
      messageType: .ext,
      seqno: seqno,
      timeout: timeout
    )
    
    return try await signClosure(transferData)
  }
}

public enum OP_AMOUNT {
  public static var CHANGE_DNS_RECORD = BigUInt(stringLiteral: "020000000")
}
