import Foundation
import TonSwift
import BigInt
import TKUIKit

public struct WithdrawModel {
  public let pool: StakingPool
  public let lpJetton: JettonInfo
  public let token: Token
  
  public init(pool: StakingPool, lpJetton: JettonInfo, token: Token) {
    self.pool = pool
    self.lpJetton = lpJetton
    self.token = token
  }
}

public struct DepositModel {
  public let pool: StakingPool
  public let token: Token
  
  public init(pool: StakingPool, token: Token) {
    self.pool = pool
    self.token = token
  }
}

public protocol StakingEditAmountController: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateConvertedValue: ((String) -> Void)? { get set }
  var didUpdateInputValue: ((String?) -> Void)? { get set }
  var didUpdateInputSymbol: ((String?) -> Void)? { get set }
  var didUpdateMaximumFractionDigits: ((Int) -> Void)? { get set }
  var didUpdateIsContinueEnabled: ((Bool) -> Void)? { get set }
  var didUpdateRemaining: ((StakingRemaining) -> Void)? { get set }
  var didUpdateIsHiddenSwapIcon: ((Bool) -> Void)? { get set }
  var didUpdateProviderModel: ((ProviderModel) -> Void)? { get set }
  var didResetMax: (() -> Void)? { get set }
  var stakingPool: StakingPool { get }
  
  func start()
  func toggleMode()
  func toggleMax()
  func setStakingPool(_ pool: StakingPool)
  func setInput(_ input: String)
  func getOptionsListModel() -> StakingOptionsListModel?
  func getStakeConfirmationItem() -> StakingConfirmationItem
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
