import Foundation
import KeeperCore
import BigInt

public struct StakingConfirmationItem {
  public enum Operation {
    case deposit(StackingPoolInfo)
    case withdraw(StackingPoolInfo)
  }
  
  public let operation: Operation
  public let amount: BigUInt
}
