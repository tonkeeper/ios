import Foundation
import TonSwift
import BigInt

public struct TransactionConfirmationModel {
  public enum Transaction {
    public struct Staking {
      public enum Flow {
        case deposit
        case withdraw(isCollect: Bool)
      }
      public let pool: StackingPoolInfo
      public let flow: Flow
    }

    public typealias IsMaxAmount = Bool
    public enum Transfer {
      case ton(IsMaxAmount)
      case jetton(JettonInfo)
      case nft(NFT)
    }
    
    case staking(Staking)
    case transfer(Transfer)
  }

  public enum Fee {
    public enum Gasless {
      case ton
      case jetton(JettonInfo)
    }
    
    case loading
    case value(Amount?, isBattery: Bool = false, gasless: Gasless?)
  }
  
  public struct Amount {
    public let token: Token
    public let value: BigUInt
  }

  public let wallet: Wallet
  public let recipient: String?
  public let recipientAddress: String?
  public let transaction: Transaction
  public let amount: Amount?
  public let fee: Fee
  public let comment: String?

  init(wallet: Wallet, 
       recipient: String?,
       recipientAddress: String?,
       transaction: Transaction,
       amount: Amount?,
       fee: Fee,
       comment: String? = nil) {
    self.wallet = wallet
    self.recipient = recipient
    self.recipientAddress = recipientAddress
    self.transaction = transaction
    self.amount = amount
    self.fee = fee
    self.comment = comment
  }
}

public enum TransactionConfirmationError: Swift.Error {
  case failedToCalculateFee
  case failedToSendTransaction
  case failedToSign
}

public protocol TransactionConfirmationController: AnyObject {
  var signHandler: ((TransferData, Wallet) async throws -> SignedTransactions?)? { get set }
  
  func getModel() -> TransactionConfirmationModel
  func emulate() async -> Result<Void, TransactionConfirmationError>
  func sendTransaction() async -> Result<Void, TransactionConfirmationError>
  
  func toggleIsPreferGasless()
}

public extension TransactionConfirmationController {
  func toggleIsPreferGasless() {}
}
