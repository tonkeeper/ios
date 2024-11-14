import Foundation
import TKCore
import KeeperCore

struct StakingDepositInputAPYAssembly {
  private init() {}
  
  static func module(wallet: Wallet,
                     stakingPool: StackingPoolInfo,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<StakingDepositInputAPYViewController, Void, StakingDepositInputAPYModuleInput> {
    let viewController = StakingDepositInputAPYViewController(
      wallet: wallet,
      stakingPool: stakingPool,
      stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
      balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
    )
    
    return MVVMModule(view: viewController, output: Void(), input: viewController)
  }
}
