import Foundation
import TKLocalize
import KeeperCore
import BigInt

final class WithdrawStakingInputViewModelConfiguration: StakingInputViewModelConfiguration {
  var didUpdateBalance: (() -> Void)?
  var didUpdateMinimumInput: (() -> Void)?
  
  var title: String { TKLocales.Unstaking.title }
  var balance: BigUInt {
    BigUInt(balanceStore.state[wallet]?.balance.stakingItems
      .first(where: { $0.poolInfo?.address == stakingPool.address })?
      .info.amount ?? 0)
  }
  var minimumInput: BigUInt?
  
  private var inputAmount: BigUInt = 0
  
  private let wallet: Wallet
  private var stakingPool: StackingPoolInfo
  private let balanceStore: ProcessedBalanceStore
  
  init(wallet: Wallet,
       stakingPool: StackingPoolInfo,
       balanceStore: ProcessedBalanceStore) {
    self.wallet = wallet
    self.stakingPool = stakingPool
    self.balanceStore = balanceStore
  }
  
  func setStakingPool(_ stakingPool: StackingPoolInfo) {}
  func setInputAmount(_ inputAmount: BigUInt) {
    self.inputAmount = inputAmount
  }
  func getStakingConfirmationItem() -> StakingConfirmationItem? {
    StakingConfirmationItem(
      operation: .withdraw(stakingPool),
      amount: inputAmount
    )
  }
}
