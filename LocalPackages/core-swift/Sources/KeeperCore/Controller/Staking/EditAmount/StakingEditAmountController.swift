import Foundation
import TonSwift
import BigInt
import TKUIKit

public protocol StakingEditAmountController: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateConvertedValue: ((String) -> Void)? { get set }
  var didUpdatePrimaryAction: ((StakingEditAmountPrimaryAction) -> Void)? { get set }
  var didUpdateInputValue: ((String?) -> Void)? { get set }
  var didUpdateInputSymbol: ((String?) -> Void)? { get set }
  var didUpdateMaximumFractionDigits: ((Int) -> Void)? { get set }
  var didUpdateRemaining: ((StakingRemaining) -> Void)? { get set }
  var didUpdateIsHiddenSwapIcon: ((Bool) -> Void)? { get set }
  var didUpdateProviderModel: ((ProviderModel) -> Void)? { get set }
  var didResetMax: (() -> Void)? { get set }
  
  var stakingPool: StakingPool { get }
  var primaryAction: StakingEditAmountPrimaryAction { get }
  var wallet: Wallet { get }
  
  func start()
  func toggleMode()
  func toggleMax()
  func setStakingPool(_ pool: StakingPool)
  func setInput(_ input: String)
  func getOptionsListModel() -> StakingOptionsListModel?
  func getStakeConfirmationItem() -> StakingConfirmationItem
}

public struct StakingEditAmountPrimaryAction {
  public enum Action {
    case confirm
    case buy
  }
  
  public var action: Action
  public var isEnable: Bool
}

public struct StakingEditAmountPoolItem {
  public let address: Address
  public let name: String
  public let icon: StakingPoolImage
  public let implementation: StakingPool.Implementation.Kind
  public let profit: String?
  public let apyPercents: String
  public let minDepositAmount: String
  public let isMaxAPY: Bool
}

public enum StakingRemaining {
  case lessThenMinDeposit(String)
  case remaining(String)
  case insufficient
}

public enum ProviderModel {
  case pool(StakingEditAmountPoolItem)
  case validationCycleEnding(String)
}
