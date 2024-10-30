import Foundation
import TonSwift
import BigInt
import TonTransport


public enum TransferData {
  public struct Ton {
    public let seqno: UInt64
    public let amount: BigUInt
    public let isMax: Bool
    public let recipient: Address
    public let isBouncable: Bool
    public let comment: String?
    public let timeout: UInt64?
    
    public init(seqno: UInt64,
                amount: BigUInt,
                isMax: Bool,
                recipient: Address,
                isBouncable: Bool = true,
                comment: String?,
                timeout: UInt64?) {
      self.seqno = seqno
      self.amount = amount
      self.isMax = isMax
      self.recipient = recipient
      self.isBouncable = isBouncable
      self.comment = comment
      self.timeout = timeout
    }
  }
  
  public struct Jetton {
    public let seqno: UInt64
    public let jettonAddress: Address
    public let amount: BigUInt
    public let recipient: Address
    public let isBouncable: Bool
    public let comment: String?
    public let timeout: UInt64?
    public let customPayload: Cell?
    public let stateInit: StateInit?
    
    public init(seqno: UInt64,
                jettonAddress: Address,
                amount: BigUInt,
                recipient: Address,
                isBouncable: Bool = true,
                comment: String?,
                timeout: UInt64?,
                customPayload: Cell? = nil,
                stateInit: StateInit? = nil
    ) {
      self.seqno = seqno
      self.jettonAddress = jettonAddress
      self.amount = amount
      self.recipient = recipient
      self.isBouncable = isBouncable
      self.comment = comment
      self.timeout = timeout
      self.customPayload = customPayload
      self.stateInit = stateInit
    }
  }
  
  public struct NFT {
    public let seqno: UInt64
    public let nftAddress: Address
    public let recipient: Address
    public let isBounceable: Bool
    public let transferAmount: BigUInt
    public let timeout: UInt64?
    public let forwardPayload: Cell?
    
    public init(seqno: UInt64,
                nftAddress: Address,
                recipient: Address,
                isBouncable: Bool = true,
                transferAmount: BigUInt,
                timeout: UInt64?,
                forwardPayload: Cell?) {
      self.seqno = seqno
      self.nftAddress = nftAddress
      self.recipient = recipient
      self.isBounceable = isBouncable
      self.transferAmount = transferAmount
      self.timeout = timeout
      self.forwardPayload = forwardPayload
    }
  }
  
  public struct Swap {
    public let seqno: UInt64
    public let minAskAmount: BigUInt
    public let offerAmount: BigUInt
    public let jettonToWalletAddress: Address
    public let jettonFromWalletAddress: Address
    public let forwardAmount: BigUInt
    public let attachedAmount: BigUInt
    public let timeout: UInt64?
    
    public init(seqno: UInt64,
                minAskAmount: BigUInt,
                offerAmount: BigUInt,
                jettonToWalletAddress: Address,
                jettonFromWalletAddress: Address,
                forwardAmount: BigUInt,
                attachedAmount: BigUInt,
                timeout: UInt64?) {
      self.seqno = seqno
      self.minAskAmount = minAskAmount
      self.offerAmount = offerAmount
      self.jettonToWalletAddress = jettonToWalletAddress
      self.jettonFromWalletAddress = jettonFromWalletAddress
      self.forwardAmount = forwardAmount
      self.attachedAmount = attachedAmount
      self.timeout = timeout
    }
  }
  
  public struct TonConnect {
    public struct Payload {
      public let value: BigInt
      public let recipientAddress: AnyAddress
      public let stateInit: String?
      public let payload: String?
      
      public init(value: BigInt,
                  recipientAddress: AnyAddress,
                  stateInit: String?,
                  payload: String?) {
        self.value = value
        self.recipientAddress = recipientAddress
        self.stateInit = stateInit
        self.payload = payload
      }
    }
    
    public let seqno: UInt64
    public let payloads: [Payload]
    public let sender: Address?
    public let timeout: UInt64
    
    public init(seqno: UInt64,
                payloads: [Payload],
                sender: Address?,
                timeout: UInt64) {
      self.seqno = seqno
      self.payloads = payloads
      self.sender = sender
      self.timeout = timeout
    }
  }
  
  public enum ChangeDNSRecord {
    
    public struct LinkDNS {
      public let seqno: UInt64
      public let nftAddress: Address
      public let linkAddress: Address?
      public let linkAmount: BigUInt
      public let timeout: UInt64
      
      public init(seqno: UInt64,
                  nftAddress: Address,
                  linkAddress: Address?,
                  linkAmount: BigUInt,
                  timeout: UInt64) {
        self.seqno = seqno
        self.nftAddress = nftAddress
        self.linkAddress = linkAddress
        self.linkAmount = linkAmount
        self.timeout = timeout
      }
    }
    
    public struct RenewDNS {
      public let seqno: UInt64
      public let nftAddress: Address
      public let linkAmount: BigUInt
      public let timeout: UInt64?
      
      public init(seqno: UInt64,
                  nftAddress: Address,
                  linkAmount: BigUInt,
                  timeout: UInt64?) {
        self.seqno = seqno
        self.nftAddress = nftAddress
        self.linkAmount = linkAmount
        self.timeout = timeout
      }
    }
    
    case link(LinkDNS)
    case renew(RenewDNS)
  }
  
  public enum Stake {
    case deposit(StakeDeposit)
    case withdraw(StakeWithdraw)
  }
  
  public struct StakeDeposit {
    public let seqno: UInt64
    public let pool: StackingPoolInfo
    public let amount: BigUInt
    public let isBouncable: Bool
    public let timeout: UInt64?
  }
  
  public struct StakeWithdraw {
    public let seqno: UInt64
    public let pool: StackingPoolInfo
    public let amount: BigUInt
    public let isBouncable: Bool
    public let timeout: UInt64?
    public let jettonWalletAddress: (_ wallet: Wallet, _ jettonMasterAddress: Address?) async throws -> Address
  }
  
  case ton(Ton)
  case jetton(Jetton)
  case nft(NFT)
  case swap(Swap)
  case tonConnect(TonConnect)
  case changeDNSRecord(ChangeDNSRecord)
  case stake(Stake)
}

public struct TransferMessageBuilder {
  public let transferData: TransferData
  
  public let queryId: BigUInt
  
  public init(transferData: TransferData) {
    self.transferData = transferData
    self.queryId = TransferMessageBuilder.newWalletQueryId()
  }
  
  static func newWalletQueryId() -> BigUInt {
    let tonkeeperSignature: [UInt8] = [0x54, 0x6d, 0xe4, 0xef]
    
    var randomBytes = [UInt8](repeating: 0, count: 4)
    arc4random_buf(&randomBytes, 4)
    
    let hexString = Data(tonkeeperSignature + randomBytes).hexString()
    return BigUInt(hexString, radix: 16) ?? BigUInt(0)
  }
  
  public func createBoc(signClosure: (TransferMessageBuilder) async throws -> String) async throws -> String {
    try await signClosure(self)
  }
  
  public func externalSign(wallet: Wallet,
                           signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    switch transferData {
    case .ton(let ton):
      return try await TonTransferMessageBuilder.sendTonTransfer(
        wallet: wallet,
        seqno: ton.seqno,
        value: ton.amount,
        isMax: ton.isMax,
        recipientAddress: ton.recipient,
        isBounceable: ton.isBouncable,
        comment: ton.comment,
        timeout: ton.timeout,
        signClosure: signClosure
      )
    case .jetton(let jetton):
      return try await TokenTransferMessageBuilder.sendTokenTransfer(
        wallet: wallet,
        seqno: jetton.seqno,
        tokenAddress: jetton.jettonAddress,
        value: jetton.amount,
        recipientAddress: jetton.recipient,
        isBounceable: jetton.isBouncable,
        comment: jetton.comment,
        timeout: jetton.timeout,
        signClosure: signClosure,
        customPayload: jetton.customPayload,
        stateInit: jetton.stateInit
      )
    case .nft(let nft):
      return try await NFTTransferMessageBuilder.sendNFTTransfer(
        wallet: wallet,
        seqno: nft.seqno,
        nftAddress: nft.nftAddress,
        recipientAddress: nft.recipient,
        isBounceable: nft.isBounceable,
        transferAmount: nft.transferAmount,
        timeout: nft.timeout,
        forwardPayload: nft.forwardPayload,
        signClosure: signClosure
      )
    case .swap(let swap):
      return try await SwapMessageBuilder.sendSwap(
        wallet: wallet,
        seqno: swap.seqno,
        minAskAmount: swap.minAskAmount,
        offerAmount: swap.offerAmount,
        jettonToWalletAddress: swap.jettonToWalletAddress,
        jettonFromWalletAddress: swap.jettonFromWalletAddress,
        forwardAmount: swap.forwardAmount,
        attachedAmount: swap.attachedAmount,
        timeout: swap.timeout,
        signClosure: signClosure
      )
    case .tonConnect(let tonConnect):
      return try await TonConnectTransferMessageBuilder.sendTonConnectTransfer(
        wallet: wallet,
        seqno: tonConnect.seqno,
        payloads: tonConnect.payloads.map {
          TonConnectTransferMessageBuilder.Payload(
            value: $0.value,
            recipientAddress: $0.recipientAddress,
            stateInit: $0.stateInit,
            payload: $0.payload
          )
        },
        sender: tonConnect.sender,
        timeout: tonConnect.timeout,
        signClosure: signClosure
      )
    case .changeDNSRecord(let changeDNS):
      switch changeDNS {
      case .link(let link):
        return try await ChangeDNSRecordMessageBuilder.linkDNSMessage(
          wallet: wallet,
          seqno: link.seqno,
          nftAddress: link.nftAddress,
          linkAddress: link.linkAddress,
          linkAmount: link.linkAmount,
          timeout: link.timeout,
          signClosure: signClosure
        )
      case .renew(let renew):
        return try await ChangeDNSRecordMessageBuilder.renewDNSMessage(
          wallet: wallet,
          seqno: renew.seqno,
          nftAddress: renew.nftAddress,
          linkAmount: renew.linkAmount,
          timeout: renew.timeout,
          signClosure: signClosure
        )
      }
    case .stake(let stake):
      switch stake {
      case .deposit(let stakeDeposit):
        switch stakeDeposit.pool.implementation.type {
        case .liquidTF:
          return try await StakeMessageBuilder.liquidTFDepositMessage(
            wallet: wallet,
            seqno: stakeDeposit.seqno,
            queryId: TransferMessageBuilder.newWalletQueryId(),
            poolAddress: stakeDeposit.pool.address,
            amount: stakeDeposit.amount,
            bounce: stakeDeposit.isBouncable,
            timeout: stakeDeposit.timeout,
            signClosure: signClosure
          )
        case .whales:
          return try await StakeMessageBuilder.whalesDepositMessage(
            wallet: wallet,
            seqno: stakeDeposit.seqno,
            queryId: TransferMessageBuilder.newWalletQueryId(),
            poolAddress: stakeDeposit.pool.address,
            amount: stakeDeposit.amount,
            forwardAmount: 100_000,
            bounce: stakeDeposit.isBouncable,
            timeout: stakeDeposit.timeout,
            signClosure: signClosure
          )
        case .tf:
          return try await StakeMessageBuilder.tfDepositMessage(
            wallet: wallet,
            seqno: stakeDeposit.seqno,
            queryId: TransferMessageBuilder.newWalletQueryId(),
            poolAddress: stakeDeposit.pool.address,
            amount: stakeDeposit.amount,
            bounce: stakeDeposit.isBouncable,
            timeout: stakeDeposit.timeout,
            signClosure: signClosure
          )
        }
      case .withdraw(let stakeWithdraw):
        switch stakeWithdraw.pool.implementation.type {
        case .liquidTF:
          return try await StakeMessageBuilder.liquidTFWithdrawMessage(
            wallet: wallet,
            seqno: stakeWithdraw.seqno,
            queryId: TransferMessageBuilder.newWalletQueryId(),
            jettonWalletAddress: stakeWithdraw.jettonWalletAddress(wallet, stakeWithdraw.pool.liquidJettonMaster),
            amount: stakeWithdraw.amount,
            withdrawFee: stakeWithdraw.pool.implementation.withdrawalFee,
            bounce: stakeWithdraw.isBouncable,
            timeout: stakeWithdraw.timeout,
            signClosure: signClosure
          )
        case .whales:
          return try await StakeMessageBuilder.whalesWithdrawMessage(
            wallet: wallet,
            seqno: stakeWithdraw.seqno,
            queryId: TransferMessageBuilder.newWalletQueryId(),
            poolAddress: stakeWithdraw.pool.address,
            amount: stakeWithdraw.amount,
            withdrawFee: stakeWithdraw.pool.implementation.withdrawalFee,
            forwardAmount: 100_000,
            bounce: stakeWithdraw.isBouncable,
            timeout: stakeWithdraw.timeout,
            signClosure: signClosure
          )
        case .tf:
          return try await StakeMessageBuilder.tfWithdrawMessage(
            wallet: wallet,
            seqno: stakeWithdraw.seqno,
            queryId: TransferMessageBuilder.newWalletQueryId(),
            poolAddress: stakeWithdraw.pool.address,
            amount: stakeWithdraw.amount,
            bounce: stakeWithdraw.isBouncable,
            timeout: stakeWithdraw.timeout,
            signClosure: signClosure
          )
        }
      }
    }
  }
}

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
    let recipientAddress: AnyAddress
    let stateInit: String?
    let payload: String?
    
    public init(value: BigInt,
                recipientAddress: AnyAddress,
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
        body = try Cell.fromBase64(src: messagePayload.fixBase64())
      }
      return MessageRelaxed.internal(
        to: payload.recipientAddress.address,
        value: payload.value.magnitude,
        bounce: {
          switch payload.recipientAddress {
          case .address: return true
          case .friendlyAddress(let friendlyAddress): return friendlyAddress.isBounceable
          }
        }(),
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
                                       signClosure: (WalletTransfer) async throws -> Data,
                                       customPayload: Cell? = nil,
                                       stateInit: StateInit? = nil) async throws -> String {
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
            comment: comment,
            customPayload: customPayload,
            stateInit: stateInit
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
    let transfer = try contract.createTransfer(args: transferData, messageType: .ext)
    let signedTransfer = try await signClosure(transfer)
    
    let signingMessage = wallet.isLedger ? try TonTransport.buildTransfer(transaction: try Transaction.from(transfer: transfer)[0]).signingMessage : transfer.signingMessage
    
    let body = Builder()
    
    switch transfer.signaturePosition {
    case .front:
      try body.store(data: signedTransfer)
      try body.store(signingMessage)
    case .tail:
      try body.store(signingMessage)
      try body.store(data: signedTransfer)
      
    }
    let transferCell = try body.endCell()
    
    let externalMessage = Message.external(to: sender,
                                           stateInit: seqno == 0 ? contract.stateInit : nil,
                                           body: transferCell)
    let cell = try Builder().store(externalMessage).endCell()
    return try cell.toBoc().base64EncodedString()
  }
}
