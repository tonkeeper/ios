import Foundation
import TonSwift
import BigInt

public struct NFTTransferBuilder {
  private init() {}
  public static func createWalletTransfer(wallet: Wallet,
                                          seqno: UInt64,
                                          nftAddress: Address,
                                          recipientAddress: Address,
                                          responseAddress: Address?,
                                          isBounceable: Bool = true,
                                          transferAmount: BigUInt,
                                          timeout: UInt64?,
                                          forwardPayload: Cell?,
                                          messageType: MessageType) throws -> WalletTransfer {
    return try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try NFTTransferMessage.internalMessage(
          nftAddress: nftAddress,
          nftTransferAmount: transferAmount,
          bounce: isBounceable,
          to: recipientAddress,
          responseAddress: responseAddress ?? sender,
          forwardPayload: forwardPayload)
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
}
