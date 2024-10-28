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
    
    case staking(Staking)
  }
  
  public struct Amount {
    public let value: BigUInt
    public let decimals: Int
    public let currency: Currency
  }
  
  public enum Fee {
    case loading
    case value(Amount?, converted: Amount?)
  }

  
  public let wallet: Wallet
  public let recipient: String?
  public let recipientAddress: String?
  public let transaction: Transaction
  public let amount: (amount: Amount, converted: Amount?)
  public let fee: Fee
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
