import BigInt
import Foundation
import TonSwift

public struct ChangeDNSRecordTransferBuilder {
    private init() {}

    public static func createLinkDNSWalletTransfer(
        wallet: Wallet,
        seqno: UInt64,
        nftAddress: Address,
        linkAddress: Address?,
        linkAmount: BigUInt,
        timeout: UInt64?,
        messageType: MessageType
    ) throws -> WalletTransfer {
        try WalletTransferBuilder.buildWalletTransfer(
            wallet: wallet,
            sender: wallet.address,
            seqno: seqno,
            internalMessages: { _ in
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

    public static func createRenewDNSWalletTransfer(
        wallet: Wallet,
        seqno: UInt64,
        nftAddress: Address,
        linkAmount: BigUInt,
        timeout: UInt64?,
        messageType: MessageType
    ) throws -> WalletTransfer {
        try WalletTransferBuilder.buildWalletTransfer(
            wallet: wallet,
            sender: wallet.address,
            seqno: seqno,
            internalMessages: { _ in
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

// let renewData = DNSRenewData(queryId: UInt64(Date().timeIntervalSince1970))
// let builder = Builder()
// try renewData.storeTo(builder: builder)
// let body = try builder.endCell()
// let messages = [
//  MessageRelaxed.internal(
//    to: nftAddress,
//    value: linkAmount,
//    bounce: true,
//    body: body
//  )
// ]
//
// return try WalletTransferBuilder.buildWalletTransfer(
//  wallet: wallet,
//  sender: try wallet.address,
//  seqno: seqno,
//  internalMessages: { sender in
//    messages
//  },
//  timeout: timeout,
//  messageType: messageType
// )
