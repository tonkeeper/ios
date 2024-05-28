import Foundation
import TonSwift
import BigInt

public struct StakingConfirmationItem {
  public enum Operation {
    case deposit(DepositModel)
    case withdraw(WithdrawModel)
  }
  
  public let operatiom: Operation
  public let amount: BigUInt
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
}
