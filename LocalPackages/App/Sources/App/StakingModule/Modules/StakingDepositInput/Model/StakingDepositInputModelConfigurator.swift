import Foundation
import KeeperCore
import TonSwift
import BigInt

final class StakingDepositInputModelConfigurator: StakingInputModelConfigurator {
  var title: String {
    "Stake"
  }
  
  var didUpdateBalance: ((UInt64) -> Void)?
  var stakingPoolInfo: StackingPoolInfo?
  
  func getBalance() -> UInt64 {
    guard let address = try? wallet.friendlyAddress else { return 0 }
    return UInt64((balanceStore.getState()[address]?.balance.tonBalance.tonBalance.amount ?? 0))
  }

  private let wallet: Wallet
  private let balanceStore: ConvertedBalanceStore
  
  init(wallet: Wallet,
       balanceStore: ConvertedBalanceStore) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    
    self.balanceStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      guard let address = try? wallet.friendlyAddress else { return }
      observer.didUpdateBalance?(UInt64(newState[address]?.balance.tonBalance.tonBalance.amount ?? 0))
    }
  }
  
  func getStakingConfirmationItem(tonAmount: BigUInt, isMaxAmount: Bool) -> StakingConfirmationItem? {
    guard let stakingPoolInfo = self.stakingPoolInfo else { return nil }
    let item = StakingConfirmationItem(
      operation: .deposit(
        stakingPoolInfo
      ),
      amount: tonAmount,
      isMax: isMaxAmount
    )
    return item
  }
  
  func isContinueEnable(tonAmount: BigUInt) -> Bool {
    guard let selectedPool = stakingPoolInfo else {
      return false
    }
    let isInputNotZero = !tonAmount.isZero
    let isAvailableAmount = tonAmount <= BigUInt(integerLiteral: getBalance())
    let isGreaterThanMinimum = tonAmount >= BigUInt(selectedPool.minStake)
    
    return isInputNotZero && isAvailableAmount && isGreaterThanMinimum
  }
  
  func getStakingInputRemainingItem(tonAmount: BigUInt) -> StakingInputRemainingItem {
    let tonBalance = getBalance()
    guard tonAmount > 0 else {
      let remaining = BigUInt(UInt64(tonBalance)) - tonAmount
      return .remaining(remaining, TonInfo.fractionDigits)
    }
    
    guard tonAmount <= BigUInt(UInt64(tonBalance)) else {
      return .insufficient
    }
    
    guard let stakingPoolInfo else {
      return .lessThanMinDeposit(0, TonInfo.fractionDigits)
    }
    
    guard tonAmount >= BigUInt(UInt64(stakingPoolInfo.minStake)) else {
      return .lessThanMinDeposit(BigUInt(UInt64(stakingPoolInfo.minStake)), TonInfo.fractionDigits)
    }
    
    let remaining = BigUInt(UInt64(tonBalance)) - tonAmount
    return .remaining(remaining, TonInfo.fractionDigits)
  }
}
