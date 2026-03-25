import BigInt
import Foundation
import TonSwift

public struct JettonTransferBuilder {
    private init() {}
    public static func createWalletTransfer(
        transferAmount: BigUInt,
        wallet: Wallet,
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
        messageType: MessageType,
        additionalInternalMessages: [MessageRelaxed]
    ) throws -> WalletTransfer {
        try WalletTransferBuilder.buildWalletTransfer(
            wallet: wallet,
            sender: wallet.address,
            seqno: seqno,
            internalMessages: { sender in
                let internalMessage = try JettonTransferMessage.internalMessage(
                    jettonAddress: tokenAddress,
                    amount: BigInt(value),
                    bounce: isBounceable,
                    to: recipientAddress,
                    from: responseAddress ?? sender,
                    transferAmount: transferAmount,
                    comment: comment,
                    customPayload: customPayload,
                    stateInit: stateInit
                )
                return CollectionOfOne(internalMessage) + additionalInternalMessages
            },
            timeout: timeout,
            messageType: messageType
        )
    }
}
