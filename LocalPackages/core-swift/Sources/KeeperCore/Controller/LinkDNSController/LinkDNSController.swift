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
    let boc = try await createBoc(dnsLink: dnsLink) { transferMessageBuilder in
      try await transferMessageBuilder.externalSign(wallet: wallet) { walletTransfer in
        try walletTransfer.signMessage(signer: WalletTransferEmptyKeySigner())
      }
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
                                  signClosure: (TransferMessageBuilder) async throws -> String?) async throws {
    let indexingLatency = try await sendService.getIndexingLatency(wallet: wallet)
    if indexingLatency > (TonSwift.DEFAULT_TTL - 30) {
      throw Error.indexerOffline
    }
    
    let boc = try await createBoc(dnsLink: dnsLink) { transferMessageBuilder in
      guard let boc = try await signClosure(transferMessageBuilder) else {
        throw Error.failedToSign
      }
      return boc
    }

    try await sendService.sendTransaction(boc: boc, wallet: wallet)
  }
}

private extension LinkDNSController {
  func createBoc(dnsLink: DNSLink, signClosure: (TransferMessageBuilder) async throws -> String) async throws -> String {
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
    
    return try await TransferMessageBuilder(
      transferData: .changeDNSRecord(
        .link(
          TransferData.ChangeDNSRecord.LinkDNS(
            seqno: seqno,
            nftAddress: nft.address,
            linkAddress: linkAddress,
            linkAmount: linkAmount,
            timeout: timeout
          )
        )
      )
    ).createBoc(signClosure: signClosure)
  }
}

public enum OP_AMOUNT {
  public static var CHANGE_DNS_RECORD = BigUInt(stringLiteral: "020000000")
}
