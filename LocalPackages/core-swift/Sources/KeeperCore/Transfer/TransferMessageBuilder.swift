import Foundation
import TonSwift
import BigInt

public struct TonTransferMessageBuilder {
  private init() {}
  public static func sendTonTransfer(wallet: Wallet,
                                     seqno: UInt64,
                                     value: BigUInt,
                                     isMax: Bool,
                                     recipientAddress: Address,
                                     isBounceable: Bool = true,
                                     comment: String?,
                                     signClosure: (WalletTransfer) async throws -> Cell) async throws -> String {
    return try await ExternalMessageTransferBuilder.externalMessageTransfer(
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
      signClosure: signClosure)
  }
}

public struct TonConnectTransferMessageBuilder {
  private init() {}
  
  public struct Payload {
    let value: BigInt
    let recipientAddress: Address
    let stateInit: String?
    let payload: String?
    
    public init(value: BigInt,
                recipientAddress: Address,
                stateInit: String?,
                payload: String?) {
      self.value = value
      self.recipientAddress = recipientAddress
      self.stateInit = stateInit
      self.payload = payload
    }
  }
  
  public static func sendTonConnectTransfer(wallet: Wallet,
                                            seqno: UInt64,
                                            payloads: [Payload],
                                            sender: Address? = nil,
                                            signClosure: (WalletTransfer) async throws -> Cell) async throws -> String {
    let messages = try payloads.map { payload in
      var stateInit: StateInit?
      if let stateInitString = payload.stateInit {
        stateInit = try StateInit.loadFrom(
          slice: try Cell
            .fromBase64(src: stateInitString)
            .toSlice()
        )
      }
      var body: Cell = .empty
      if let messagePayload = payload.payload {
        body = try Cell.fromBase64(src: messagePayload)
      }
      return MessageRelaxed.internal(
        to: payload.recipientAddress,
        value: payload.value.magnitude,
        bounce: false,
        stateInit: stateInit,
        body: body)
    }
    return try await ExternalMessageTransferBuilder
      .externalMessageTransfer(
        wallet: wallet,
        sender: sender ?? (try wallet.address),
        seqno: seqno, internalMessages: { sender in
          messages
        },
        signClosure: signClosure)
  }
}

public struct TokenTransferMessageBuilder {
  private init() {}
  public static func sendTokenTransfer(wallet: Wallet,
                                       seqno: UInt64,
                                       tokenAddress: Address,
                                       value: BigUInt,
                                       recipientAddress: Address,
                                       isBounceable: Bool = true,
                                       comment: String?,
                                       signClosure: (WalletTransfer) async throws -> Cell) async throws -> String {
    return try await ExternalMessageTransferBuilder
      .externalMessageTransfer(
        wallet: wallet,
        sender: try wallet.address,
        seqno: seqno, internalMessages: { sender in
          let internalMessage = try JettonTransferMessage.internalMessage(
            jettonAddress: tokenAddress,
            amount: BigInt(value),
            bounce: isBounceable,
            to: recipientAddress,
            from: sender,
            comment: comment
          )
          return [internalMessage]
        },
        signClosure: signClosure)
  }
}

public struct NFTTransferMessageBuilder {
  private init() {}
  public static func sendNFTTransfer(wallet: Wallet,
                                     seqno: UInt64,
                                     nftAddress: Address,
                                     recipientAddress: Address,
                                     isBounceable: Bool = true,
                                     transferAmount: BigUInt,
                                     signClosure: (WalletTransfer) async throws -> Cell) async throws -> String {
    return try await ExternalMessageTransferBuilder
      .externalMessageTransfer(
        wallet: wallet,
        sender: try wallet.address,
        seqno: seqno, internalMessages: { sender in
          let internalMessage = try NFTTransferMessage.internalMessage(
            nftAddress: nftAddress,
            nftTransferAmount: transferAmount,
            bounce: isBounceable,
            to: recipientAddress,
            from: sender,
            forwardPayload: nil)
          return [internalMessage]
        },
        signClosure: signClosure)
  }
}

public struct ExternalMessageTransferBuilder {
  private init() {}
  public static func externalMessageTransfer(wallet: Wallet,
                                             sender: Address,
                                             sendMode: SendMode = .walletDefault(),
                                             seqno: UInt64,
                                             internalMessages: (_ sender: Address) throws -> [MessageRelaxed],
                                             signClosure: (WalletTransfer) async throws -> Cell) async throws -> String {
    let internalMessages = try internalMessages(sender)
    let transferData = WalletTransferData(
      seqno: seqno,
      messages: internalMessages,
      sendMode: sendMode,
      timeout: nil)
    let contract = try wallet.contract
    let transfer = try contract.createTransfer(args: transferData)
    let transferCell = try await signClosure(transfer)
    let externalMessage = Message.external(to: sender,
                                           stateInit: contract.stateInit,
                                           body: transferCell)
    let cell = try Builder().store(externalMessage).endCell()
    return try cell.toBoc().base64EncodedString()
  }
}
