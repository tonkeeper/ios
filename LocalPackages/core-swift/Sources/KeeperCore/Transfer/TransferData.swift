import Foundation
import TonSwift
import BigInt

public struct TransferData {
  public struct Ton {
    public let amount: BigUInt
    public let isMax: Bool
    public let recipient: Address
    public let isBouncable: Bool
    public let comment: String?
    
    public init(amount: BigUInt,
                isMax: Bool,
                recipient: Address,
                isBouncable: Bool = true,
                comment: String?) {
      self.amount = amount
      self.isMax = isMax
      self.recipient = recipient
      self.isBouncable = isBouncable
      self.comment = comment
    }
  }
  
  public struct Jetton {
    public let jettonAddress: Address
    public let amount: BigUInt
    public let recipient: Address
    public let responseAddress: Address?
    public let isBouncable: Bool
    public let comment: String?
    public let customPayload: Cell?
    public let stateInit: StateInit?
    
    public init(jettonAddress: Address,
                amount: BigUInt,
                recipient: Address,
                responseAddress: Address?,
                isBouncable: Bool = true,
                comment: String?,
                customPayload: Cell? = nil,
                stateInit: StateInit? = nil
    ) {
      self.jettonAddress = jettonAddress
      self.amount = amount
      self.recipient = recipient
      self.responseAddress = responseAddress
      self.isBouncable = isBouncable
      self.comment = comment
      self.customPayload = customPayload
      self.stateInit = stateInit
    }
  }
  
  public struct NFT {
    public let nftAddress: Address
    public let recipient: Address
    public let responseAddress: Address?
    public let isBounceable: Bool
    public let transferAmount: BigUInt
    public let forwardPayload: Cell?
    
    public init(nftAddress: Address,
                recipient: Address,
                responseAddress: Address?,
                isBouncable: Bool = true,
                transferAmount: BigUInt,
                forwardPayload: Cell?) {
      self.nftAddress = nftAddress
      self.recipient = recipient
      self.responseAddress = responseAddress
      self.isBounceable = isBouncable
      self.transferAmount = transferAmount
      self.forwardPayload = forwardPayload
    }
  }
  
  public struct Swap {
    public let minAskAmount: BigUInt
    public let offerAmount: BigUInt
    public let jettonToWalletAddress: Address
    public let jettonFromWalletAddress: Address
    public let forwardAmount: BigUInt
    public let attachedAmount: BigUInt
    
    public init(minAskAmount: BigUInt,
                offerAmount: BigUInt,
                jettonToWalletAddress: Address,
                jettonFromWalletAddress: Address,
                forwardAmount: BigUInt,
                attachedAmount: BigUInt) {
      self.minAskAmount = minAskAmount
      self.offerAmount = offerAmount
      self.jettonToWalletAddress = jettonToWalletAddress
      self.jettonFromWalletAddress = jettonFromWalletAddress
      self.forwardAmount = forwardAmount
      self.attachedAmount = attachedAmount
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
    
    public let payloads: [Payload]
    public let sender: Address?
    
    public init(payloads: [Payload],
                sender: Address?) {
      self.payloads = payloads
      self.sender = sender
    }
  }
  
  public enum ChangeDNSRecord {
    
    public struct LinkDNS {
      public let nftAddress: Address
      public let linkAddress: Address?
      public let linkAmount: BigUInt
      
      public init(nftAddress: Address,
                  linkAddress: Address?,
                  linkAmount: BigUInt) {
        self.nftAddress = nftAddress
        self.linkAddress = linkAddress
        self.linkAmount = linkAmount
      }
    }
    
    public struct RenewDNS {
      public let nftAddress: Address
      public let linkAmount: BigUInt
      
      public init(nftAddress: Address,
                  linkAmount: BigUInt) {
        self.nftAddress = nftAddress
        self.linkAmount = linkAmount
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
    public let pool: StackingPoolInfo
    public let amount: BigUInt
    public let isMax: Bool
    public let isBouncable: Bool
  }
  
  public struct StakeWithdraw {
    public let pool: StackingPoolInfo
    public let amount: BigUInt
    public let isBouncable: Bool
    public let jettonWalletAddress: (_ wallet: Wallet, _ jettonMasterAddress: Address?) async throws -> Address
  }
  
  public enum Transfer {
    case ton(Ton)
    case jetton(Jetton)
    case nft(NFT)
    case swap(Swap)
    case tonConnect(TonConnect)
    case changeDNSRecord(ChangeDNSRecord)
    case stake(Stake)
  }
  
  public let transfer: Transfer
  public let wallet: Wallet
  public let messageType: MessageType
  public let seqno: UInt64
  public let timeout: UInt64?
  
  public init(transfer: Transfer,
              wallet: Wallet,
              messageType: MessageType = .ext,
              seqno: UInt64,
              timeout: UInt64?) {
    self.transfer = transfer
    self.wallet = wallet
    self.messageType = messageType
    self.seqno = seqno
    self.timeout = timeout
  }
}
