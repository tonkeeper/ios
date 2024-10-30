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
    
    public enum Transfer {
      case ton
      case jetton(JettonInfo)
      case nft(NFT)
    }
    
    case staking(Staking)
    case transfer(Transfer)
  }
  
  public struct Amount {
    public enum Item {
      case currency(Currency)
      case symbol(String)
    }
    public let value: BigUInt
    public let decimals: Int
    public let item: Item
  }
  
  public enum Fee {
    case loading
    case value(Amount?, converted: Amount?, isBattery: Bool = false)
  }

  
  public let wallet: Wallet
  public let recipient: String?
  public let recipientAddress: String?
  public let transaction: Transaction
  public let amount: (amount: Amount, converted: Amount?)?
  public let fee: Fee
  public let comment: String?
  
  init(wallet: Wallet, 
       recipient: String?,
       recipientAddress: String?,
       transaction: Transaction,
       amount: (amount: Amount, converted: Amount?)?,
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
  var signHandler: ((TransferMessageBuilder, Wallet) async throws -> String?)? { get set }
  
  func getModel() -> TransactionConfirmationModel
  func emulate() async -> Result<Void, TransactionConfirmationError>
  func sendTransaction() async -> Result<Void, TransactionConfirmationError>
}
