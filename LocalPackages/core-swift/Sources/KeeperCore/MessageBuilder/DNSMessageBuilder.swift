import Foundation
import TonSwift
import BigInt

public struct ChangeDNSRecordMessageBuilder {
  private init() {}
  public static func linkDNSMessage(wallet: Wallet, 
                                    seqno: UInt64,
                                    nftAddress: Address,
                                    linkAddress: Address?,
                                    linkAmount: BigUInt,
                                    timeout: UInt64?,
                                    signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    return try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      sendMode: .walletDefault(),
      seqno: seqno,
      internalMessages: {
        sender in
        let internalMessage = try DNSLinkMessage.internalMessage(
          nftAddress: nftAddress,
          linkAddress: linkAddress,
          dnsLinkAmount: linkAmount,
          stateInit: try? wallet.stateInit
        )
        return [internalMessage]
      },
      timeout: timeout,
      signClosure: signClosure
    )
  }
  
  public static func renewDNSMessage(wallet: Wallet,
                                     seqno: UInt64,
                                     nftAddress: Address,
                                     linkAmount: BigUInt,
                                     timeout: UInt64?,
                                     signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    return try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      sendMode: .walletDefault(),
      seqno: seqno,
      internalMessages: {
        sender in
        let internalMessage = try DNSRenewMessage.internalMessage(
          nftAddress: nftAddress,
          dnsLinkAmount: linkAmount,
          stateInit: try? wallet.stateInit
        )
        return [internalMessage]
      },
      timeout: timeout,
      signClosure: signClosure
    )
  }
}

