import Foundation
import TonSwift
import BigInt

public enum StakingTransactionSendingStatus {
  case ready
  case feeIsNotSet
  case insufficientFunds(InsufficientFunds)
  
  public struct InsufficientFunds {
    public let estimatedFee: BigUInt
    public let refundedAmount: BigUInt
    public let token: Token
    public let wallet: Wallet
  }
}

public struct StakingConfirmationItem {
  public enum Operation {
    case deposit(StakingPool)
    case withdraw(StakingPool)
  }
  
  public let operatiom: Operation
  public let amount: BigUInt
  public let isMax: Bool
}

public enum StakingConfirmationError: Swift.Error {
  case failedToCalculateFee
  case failedToSendTransaction
  case failedToSign(TransferSignServiceError)
}

public protocol StakingConfirmationController: AnyObject {
  var didUpdateModel: ((StakingConfirmationModel) -> Void)? { get set }
  var didGetError: ((StakingConfirmationError) -> Void)? { get set }
  var didGetExternalSign: ((URL) async throws -> Data?)? { get set }
  
  func start() async
  func sendTransaction() async throws
  func isNeedToConfirm() -> Bool
  func checkTransactionSendingStatus() -> StakingTransactionSendingStatus
}
