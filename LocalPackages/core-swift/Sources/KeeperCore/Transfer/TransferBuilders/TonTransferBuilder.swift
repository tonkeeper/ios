import Foundation
import TonSwift
import BigInt

public struct TonTransferBuilder {
  private init() {}
  public static func createWalletTransfer(wallet: Wallet,
                                          seqno: UInt64,
                                          value: BigUInt,
                                          isMax: Bool,
                                          recipientAddress: Address,
                                          isBounceable: Bool = true,
                                          comment: String?,
                                          timeout: UInt64?,
                                          messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      sendMode: isMax ? .sendMaxTon() : .walletDefault(),
      seqno: seqno,
      internalMessages: { _ in
        let internalMessage: MessageRelaxed
        if let comment = comment {
          internalMessage = try MessageRelaxed.internal(to: recipientAddress,
                                                        value: value.magnitude,
                                                        bounce: isBounceable,
                                                        textPayload: comment)
        } else {
          internalMessage = MessageRelaxed.internal(to: recipientAddress,
                                                    value: value.magnitude,
                                                    bounce: isBounceable)
        }
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
}
