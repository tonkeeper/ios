import Foundation
import TKLocalize
import KeeperCore
import BigInt

final class DepositStakingInputViewModelConfiguration: StakingInputViewModelConfiguration {
  var didUpdateBalance: (() -> Void)?
  var didUpdateMinimumInput: (() -> Void)?
  
  var title: String { TKLocales.Staking.title }
  var balance: BigUInt {
    BigUInt(balanceStore.state[wallet]?.balance.tonItem.amount ?? 0)
  }
  var minimumInput: BigUInt? {
    BigUInt(stakingPool?.minStake ?? 0)
  }
  
  private var inputAmount: BigUInt = 0
  
  private let wallet: Wallet
  private var stakingPool: StackingPoolInfo?
  private let balanceStore: ProcessedBalanceStore
  
  init(wallet: Wallet,
       stakingPool: StackingPoolInfo?,
       balanceStore: ProcessedBalanceStore) {
    self.wallet = wallet
    self.stakingPool = stakingPool
    self.balanceStore = balanceStore
  }
  
  func setStakingPool(_ stakingPool: StackingPoolInfo) {
    self.stakingPool = stakingPool
    didUpdateBalance?()
    didUpdateMinimumInput?()
  }
  
  func setInputAmount(_ inputAmount: BigUInt) {
    self.inputAmount = inputAmount
  }
  
  func getStakingConfirmationItem() -> StakingConfirmationItem? {
    guard let stakingPool else { return nil }
    return StakingConfirmationItem(
      operation: .deposit(stakingPool),
      amount: inputAmount
    )
  }
}
