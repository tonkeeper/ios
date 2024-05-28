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
  private let mnemonicRepository: WalletMnemonicRepository
  
  init(wallet: Wallet, 
       nft: NFT,
       sendService: SendService,
       mnemonicRepository: WalletMnemonicRepository) {
    self.wallet = wallet
    self.nft = nft
    self.sendService = sendService
    self.mnemonicRepository = mnemonicRepository
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
                                  externalSign: ((URL, Wallet) async throws -> Data)) async throws {
    let boc = try await createBoc(dnsLink: dnsLink) { transfer in
      try await self.signTransfer(transfer,  externalSign: externalSign)
    }
    try await sendService.sendTransaction(boc: boc, wallet: wallet)
  }
}

private extension LinkDNSController {
  func createBoc(dnsLink: DNSLink, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let linkAmount = OP_AMOUNT.DNS_LINK
    let linkAddress: Address?
    switch dnsLink {
    case .link(let address):
      linkAddress = address.address
    case .unlink:
      linkAddress = nil
    }
    
    return try await DNSLinkMessageBuilder.linkDNSMessage(
      wallet: wallet,
      seqno: seqno,
      nftAddress: nft.address,
      linkAddress: linkAddress,
      linkAmount: linkAmount,
      timeout: timeout,
      signClosure: signClosure)
  }
  
  // TODO: Extract from here and SendConfirmationController
  
  func signTransfer(_ transfer: WalletTransfer,
                    externalSign: ((URL, Wallet) async throws -> Data)) async throws -> Data {
    switch wallet.identity.kind {
    case .Regular:
      let mnemonic = try mnemonicRepository.getMnemonic(forWallet: wallet)
      let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
      let privateKey = keyPair.privateKey
      return try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: privateKey.data))
    case .Lockup:
      throw Error.failedToSign
    case .Watchonly:
      throw Error.failedToSign
    case .External(let publicKey, let walletContractVersion):
      guard let url = createTonSignURL(
        transfer: try transfer.signingMessage.endCell().toBoc(),
        publicKey: publicKey,
        revision: walletContractVersion
      ) else {
        throw Error.failedToSign
      }
      return try await externalSign(url, wallet)
    }
  }
  
  func createTonSignURL(transfer: Data, publicKey: TonSwift.PublicKey, revision: WalletContractVersion) -> URL? {
    guard let publicKey = publicKey.data.base64EncodedString().percentEncoded,
          let body = transfer.base64EncodedString().percentEncoded else { return nil }
    let v = revision.rawValue.lowercased()
    
    let string = "tonsign://?pk=\(publicKey)&body=\(body)&v=\(v)&return=\("tonkeeperx://publish".percentEncoded ?? "")"
    return URL(string: string)
  }
}

public enum OP_AMOUNT {
  public static var DNS_LINK = BigUInt(stringLiteral: "020000000")
}
