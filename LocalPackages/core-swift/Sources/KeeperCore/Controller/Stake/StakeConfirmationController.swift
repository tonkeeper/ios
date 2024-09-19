import Foundation
import TonSwift
import BigInt

public enum StakeConfirmationError: Swift.Error {
  case failedToCalculateFee
  case failedToSendTransaction
  case failedToSign
}

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

public protocol StakeConfirmationController: AnyObject {
  var didUpdateModel: ((StakeConfirmationModel) -> Void)? { get set }
  var didGetError: ((StakeConfirmationError) -> Void)? { get set }
  var didGetExternalSign: ((URL) async throws -> Data?)? { get set }
  
  var signHandler: ((TransferMessageBuilder, Wallet) async throws -> String?)? { get set }
  
  func start() async
  func sendTransaction() async throws
  func checkTransactionSendingStatus() async -> StakingTransactionSendingStatus
}
