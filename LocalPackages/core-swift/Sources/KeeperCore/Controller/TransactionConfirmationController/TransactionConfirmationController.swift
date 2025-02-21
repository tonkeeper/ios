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

  public struct Amount {
    public let token: Token
    public let value: BigUInt
  }
  
  public enum FeeState {
    case none
    case loading
    case fee(Fee)
  }
  
  public struct Fee {
    public let amount: Amount
    public let type: FeeType
  }
  
  public enum FeeType {
    case `default`
    case battery
    case gasless(toggleOption: Token)
  }
  
  public let wallet: Wallet
  public let recipient: String?
  public let recipientAddress: String?
  public let transaction: Transaction
  public let amount: Amount?
  public let feeState: FeeState
  public let comment: String?

  init(wallet: Wallet, 
       recipient: String?,
       recipientAddress: String?,
       transaction: Transaction,
       amount: Amount?,
       feeState: FeeState,
       comment: String? = nil) {
    self.wallet = wallet
    self.recipient = recipient
    self.recipientAddress = recipientAddress
    self.transaction = transaction
    self.amount = amount
    self.feeState = feeState
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
