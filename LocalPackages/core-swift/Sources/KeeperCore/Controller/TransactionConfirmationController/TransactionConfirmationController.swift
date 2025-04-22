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
  
  public enum ExtraState {
    case none
    case loading
    case extra(Extra)
  }
  
  public enum Extra {
    case Fee(amount: Amount, type: ExtraType)
    case Refund(amount: Amount, type: ExtraType)
  }
  
  public enum ExtraType: Equatable {
    case `default`
    case battery
    case gasless(token: JettonInfo)
  }
  
  public let wallet: Wallet
  public let recipient: String?
  public let recipientAddress: String?
  public let transaction: Transaction
  public let amount: Amount?
  public let extraState: ExtraState
  public let comment: String?
  public let availableExtraTypes: [ExtraType]

  init(wallet: Wallet, 
       recipient: String?,
       recipientAddress: String?,
       transaction: Transaction,
       amount: Amount?,
       extraState: ExtraState,
       comment: String? = nil,
       availableExtraTypes: [ExtraType]
  ) {
    self.wallet = wallet
    self.recipient = recipient
    self.recipientAddress = recipientAddress
    self.transaction = transaction
    self.amount = amount
    self.extraState = extraState
    self.comment = comment
    self.availableExtraTypes = availableExtraTypes
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
  func setLoading() -> Void
  func emulate() async -> Result<Void, TransactionConfirmationError>
  func sendTransaction() async -> Result<Void, TransactionConfirmationError>
  
  func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType)
}

public extension TransactionConfirmationController {
  func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {}
}
