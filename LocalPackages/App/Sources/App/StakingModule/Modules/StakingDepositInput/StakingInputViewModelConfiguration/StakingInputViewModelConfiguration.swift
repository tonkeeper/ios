import Foundation
import KeeperCore
import BigInt

protocol StakingInputViewModelConfiguration: AnyObject{
  var title: String { get }
  var balance: BigUInt { get }
  var minimumInput: BigUInt? { get }
  
  var didUpdateBalance: (() -> Void)? { get set }
  var didUpdateMinimumInput: (() -> Void)? { get set }
  
  func setStakingPool(_ stakingPool: StackingPoolInfo)
  func setInputAmount(_ inputAmount: BigUInt)
  func getStakingConfirmationItem() -> StakingConfirmationItem?
}
