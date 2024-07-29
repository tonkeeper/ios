import Foundation
import KeeperCore
import TonSwift
import BigInt

final class StakingWithdrawInputModelConfigurator: StakingInputModelConfigurator {
  var title: String {
    "Unstake"
  }
  
  var stakingPoolInfo: StackingPoolInfo? {
    get {
      poolInfo
    }
    set {}
  }
  
  var didUpdateBalance: ((UInt64) -> Void)?
  
  func getBalance() -> UInt64 {
    guard let address = try? wallet.friendlyAddress else { return 0 }
    return UInt64(balanceStore.getState()[address]?.balance?.stakingItems
      .first(where: { $0.poolInfo?.address == stakingPoolInfo?.address })?
      .info.amount ?? 0)
  }

  private let wallet: Wallet
  private let poolInfo: StackingPoolInfo
  private let balanceStore: ProcessedBalanceStore
  
  init(wallet: Wallet,
       poolInfo: StackingPoolInfo,
       balanceStore: ProcessedBalanceStore) {
    self.wallet = wallet
    self.poolInfo = poolInfo
    self.balanceStore = balanceStore
  }
  
  func getStakingConfirmationItem(tonAmount: BigUInt, isMaxAmount: Bool) -> StakingConfirmationItem? {
    let item = StakingConfirmationItem(
      operation: .withdraw(
        poolInfo
      ),
      amount: tonAmount,
      isMax: isMaxAmount
    )
    return item
  }
  
  func isContinueEnable(tonAmount: BigUInt) -> Bool {
    let isInputNotZero = !tonAmount.isZero
    let isAvailableAmount = tonAmount <= BigUInt(integerLiteral: getBalance())
    
    return isInputNotZero && isAvailableAmount
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

    let remaining = BigUInt(UInt64(tonBalance)) - tonAmount
    return .remaining(remaining, TonInfo.fractionDigits)
  }
}
