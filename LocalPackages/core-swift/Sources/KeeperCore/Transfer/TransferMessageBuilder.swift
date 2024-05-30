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
                                     timeout: UInt64?,
                                     signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
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
      timeout: timeout,
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
                                            timeout: UInt64?,
                                            signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
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
        timeout: timeout,
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
                                       timeout: UInt64?,
                                       signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
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
        timeout: timeout,
        signClosure: signClosure)
  }
}

public struct SwapMessageBuilder {
  private init() {}
  public static func sendSwap(wallet: Wallet,
                              seqno: UInt64,
                              minAskAmount: BigUInt,
                              offerAmount: BigUInt,
                              jettonToWalletAddress: Address,
                              jettonFromWalletAddress: Address,
                              forwardAmount: BigUInt,
                              attachedAmount: BigUInt,
                              timeout: UInt64?,
                              signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    
        
    let internalMessage = try StonfiSwapMessage.internalMessage(
      userWalletAddress: wallet.address,
      minAskAmount: minAskAmount,
      offerAmount: offerAmount,
      jettonFromWalletAddress: jettonFromWalletAddress,
      jettonToWalletAddress: jettonToWalletAddress,
      forwardAmount: forwardAmount,
      attachedAmount: attachedAmount
    )
      
    return try await ExternalMessageTransferBuilder
      .externalMessageTransfer(
        wallet: wallet,
        sender: try wallet.address,
        seqno: seqno, internalMessages: { sender in
          return [internalMessage]
        },
        timeout: timeout,
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
                                     timeout: UInt64?,
                                     forwardPayload: Cell?,
                                     signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
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
            forwardPayload: forwardPayload)
          return [internalMessage]
        },
        timeout: timeout,
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
                                             timeout: UInt64?,
                                             signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let internalMessages = try internalMessages(sender)
    let transferData = WalletTransferData(
      seqno: seqno,
      messages: internalMessages,
      sendMode: sendMode,
      timeout: timeout)
    let contract = try wallet.contract
    let transfer = try contract.createTransfer(args: transferData)
    let signedTransfer = try await signClosure(transfer)
    let body = Builder()
    try body.store(data: signedTransfer)
    try body.store(transfer.signingMessage)
    let transferCell = try body.endCell()
    
    let externalMessage = Message.external(to: sender,
                                           stateInit: contract.stateInit,
                                           body: transferCell)
    let cell = try Builder().store(externalMessage).endCell()
    return try cell.toBoc().base64EncodedString()
  }
}

public struct StakingMessageBuilder {
    private init() {}
    public static func sendStaking(wallet: Wallet,
                                   seqno: UInt64,
                                   amount: BigUInt,
                                   fromWalletAddress: Address,
                                   toWalletAddress: Address,
                                   forwardAmount: BigUInt,
                                   attachedAmount: BigUInt,
                                   timeout: UInt64?,
                                   signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
        let internalMessage = try StonfiStakingMessage.internalMessage(
            userWalletAddress: wallet.address,
            amount: amount,
            fromWalletAddress: fromWalletAddress,
            toWalletAddress: toWalletAddress,
            forwardAmount: forwardAmount,
            attachedAmount: attachedAmount
        )
        
        return try await ExternalMessageTransferBuilder
            .externalMessageTransfer(
                wallet: wallet,
                sender: try wallet.address,
                seqno: seqno, internalMessages: { sender in
                    return [internalMessage]
                },
                timeout: timeout,
                signClosure: signClosure)
    }
}

private struct StonfiStakingMessage {
    public static func internalMessage(userWalletAddress: Address,
                                       amount: BigUInt,
                                       fromWalletAddress: Address,
                                       toWalletAddress: Address,
                                       forwardAmount: BigUInt,
                                       attachedAmount: BigUInt
                                       ) throws -> MessageRelaxed {
        let queryId = UInt64(Date().timeIntervalSince1970)
                
        let forwardPayloadBuilder = Builder()
        try forwardPayloadBuilder.store(uint: 0x6ec9dc65, bits: 32)
        try forwardPayloadBuilder.store(AnyAddress.internalAddr(toWalletAddress))
        let forwardPayload = try forwardPayloadBuilder.endCell()
        
        let jettonTransferBuilder = Builder()
        try jettonTransferBuilder.store(uint: OpCodes.JETTON_TRANSFER, bits: 32)
        try jettonTransferBuilder.store(uint: queryId, bits: 64)
        try jettonTransferBuilder.storeMaybe(Coins(rawValue: amount.magnitude))
        try jettonTransferBuilder.store(AnyAddress.internalAddr(try! Address.parse(STONFI_CONSTANTS.RouterAddress)))
        try jettonTransferBuilder.store(AnyAddress.internalAddr(userWalletAddress))
        try jettonTransferBuilder.store(bit: false)
        try jettonTransferBuilder.storeMaybe(Coins(rawValue: forwardAmount.magnitude))
        try jettonTransferBuilder.storeMaybe(ref: forwardPayload)
        let jettonTransferData = try jettonTransferBuilder.endCell()
        
        return MessageRelaxed.internal(
            to: fromWalletAddress,
            value: attachedAmount,
            bounce: true,
            body: try Builder().store(jettonTransferData).endCell()
        )
    }
}
