import Foundation
import TonSwift
import BigInt

public struct ChangeDNSRecordTransferBuilder {
  private init() {}
  
  public static func createLinkDNSWalletTransfer(wallet: Wallet,
                                                 seqno: UInt64,
                                                 nftAddress: Address,
                                                 linkAddress: Address?,
                                                 linkAmount: BigUInt,
                                                 timeout: UInt64?,
                                                 messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try DNSLinkMessage.internalMessage(
          nftAddress: nftAddress,
          linkAddress: linkAddress,
          dnsLinkAmount: linkAmount,
          stateInit: try? wallet.stateInit
        )
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
  
  public static func createRenewDNSWalletTransfer(wallet: Wallet,
                                                  seqno: UInt64,
                                                  nftAddress: Address,
                                                  linkAmount: BigUInt,
                                                  timeout: UInt64?,
                                                  messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try DNSRenewMessage.internalMessage(
          nftAddress: nftAddress,
          dnsLinkAmount: linkAmount,
          stateInit: try? wallet.stateInit
        )
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
}
