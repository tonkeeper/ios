import Foundation
import TonSwift
import BigInt

public struct JettonTransferBuilder {
  private init() {}
  public static func createWalletTransfer(wallet: Wallet,
                                          seqno: UInt64,
                                          tokenAddress: Address,
                                          value: BigUInt,
                                          recipientAddress: Address,
                                          responseAddress: Address?,
                                          isBounceable: Bool = true,
                                          comment: String?,
                                          timeout: UInt64?,
                                          customPayload: Cell? = nil,
                                          stateInit: StateInit? = nil,
                                          messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try JettonTransferMessage.internalMessage(
          jettonAddress: tokenAddress,
          amount: BigInt(value),
          bounce: isBounceable,
          to: recipientAddress,
          from: responseAddress ?? sender,
          comment: comment,
          customPayload: customPayload,
          stateInit: stateInit
        )
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
}
