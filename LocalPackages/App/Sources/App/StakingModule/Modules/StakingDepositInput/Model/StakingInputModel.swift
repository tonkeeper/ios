import Foundation
import KeeperCore
import BigInt
import TonSwift

struct StakingInputModelConvertedItem {
  let amount: BigUInt
  let fractionDigits: Int
  let symbol: String
  let isIconHidden: Bool
}

struct StakingInputInputItem {
  let amount: BigUInt
  let fractionDigits: Int
  let symbol: String?
  let maximumFractionDigits: Int
}

struct StakingInputButtonItem {
  let title: String
  let isEnable: Bool
}

enum StakingInputRemainingItem {
  case lessThanMinDeposit(BigUInt, Int)
  case remaining(BigUInt, Int)
  case insufficient
}

struct StakingInputPoolInfoItem {
  let poolInfo: StackingPoolInfo
  let isMostProfitable: Bool
  let profit: BigUInt
}

public struct StakingConfirmationItem {
  public enum Operation {
    case deposit(StackingPoolInfo)
    case withdraw(StackingPoolInfo)
  }
  
  public let operation: Operation
  public let amount: BigUInt
  public let isMax: Bool
}

protocol StakingInputModelConfigurator: AnyObject {
  var title: String { get }
  var didUpdateBalance: ((UInt64) -> Void)? { get set }
  var stakingPoolInfo: StackingPoolInfo? { get set }
  func getBalance() -> UInt64
  func getStakingConfirmationItem(tonAmount: BigUInt, isMaxAmount: Bool) -> StakingConfirmationItem?
  func isContinueEnable(tonAmount: BigUInt) -> Bool
  func getStakingInputRemainingItem(tonAmount: BigUInt) -> StakingInputRemainingItem
}

protocol StakingInputModel: AnyObject {
  var title: String { get }
  var didUpdateIsMax: ((Bool) -> Void)? { get set }
  var didUpdateConvertedItem: ((StakingInputModelConvertedItem) -> Void)? { get set }
  var didUpdateInputItem: ((StakingInputInputItem) -> Void)? { get set }
  var didUpdateRemainingItem: ((StakingInputRemainingItem) -> Void)? { get set }
  var didUpdateButtonItem: ((StakingInputButtonItem) -> Void)? { get set }
  var didUpdateDetailsIsHidden: ((Bool) -> Void)? { get set }
  
  func start()
  func didEditAmountInput(_ input: String)
  func toggleInputMode()
  func toggleIsMax()
  func setSelectedStackingPool(_ pool: StackingPoolInfo)
  func getStakingConfirmationItem(completion: @escaping (StakingConfirmationItem) -> Void)
}
