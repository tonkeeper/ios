import Foundation
import TKLocalize
import KeeperCore
import TonSwift
import BigInt

final class StakingDepositInputModelConfigurator: StakingInputModelConfigurator {
  var title: String {
    TKLocales.Staking.title
  }
  
  var didUpdateBalance: ((UInt64) -> Void)?
  var stakingPoolInfo: StackingPoolInfo?
  
  func getBalance() -> UInt64 {
    let balance = UInt64(balanceStore.getState()[wallet]?.balance.tonBalance.tonBalance.amount ?? 0)
    return balance
  }

  private let wallet: Wallet
  private let balanceStore: ConvertedBalanceStore
  
  init(wallet: Wallet,
       balanceStore: ConvertedBalanceStore) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    
    balanceStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateConvertedBalance(_, let wallet):
        guard wallet == observer.wallet else { return }
        DispatchQueue.main.async {
          let balance = UInt64(observer.balanceStore.getState()[wallet]?.balance.tonBalance.tonBalance.amount ?? 0)
          observer.didUpdateBalance?(balance)
        }
      }
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
