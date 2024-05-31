import Foundation
import TonSwift
import BigInt

public final class LinkDNSController {
  public enum Error: Swift.Error {
    case failedToSign
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
    let boc = try await createBoc(dnsLink: dnsLink) { transfer in
      try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
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
                                  signClosure: (WalletTransfer) async throws -> Data?) async throws {
    let boc = try await createBoc(dnsLink: dnsLink) { transfer in
      guard let signedData = try await signClosure(transfer) else {
        throw Error.failedToSign
      }
      return signedData
    }
    try await sendService.sendTransaction(boc: boc, wallet: wallet)
  }
}

private extension LinkDNSController {
  func createBoc(dnsLink: DNSLink, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
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
    
    return try await ChangeDNSRecordMessageBuilder.linkDNSMessage(
      wallet: wallet,
      seqno: seqno,
      nftAddress: nft.address,
      linkAddress: linkAddress,
      linkAmount: linkAmount,
      timeout: timeout,
      signClosure: signClosure)
  }
}

public enum OP_AMOUNT {
  public static var CHANGE_DNS_RECORD = BigUInt(stringLiteral: "020000000")
}
