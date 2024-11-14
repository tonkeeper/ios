import Foundation
import TKCore
import KeeperCore

struct StakingDepositInputPoolPickerAssembly {
  private init() {}
  
  static func module(wallet: Wallet,
                     selectedStakingPool: StackingPoolInfo?,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<StakingDepositInputPoolPickerViewController, StakingDepositInputPoolPickerModuleOutput, StakingDepositInputPoolPickerModuleInput> {
    let viewController = StakingDepositInputPoolPickerViewController(
      wallet: wallet,
      selectedStakingPool: selectedStakingPool,
      stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
      processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    
    return MVVMModule(view: viewController, output: viewController, input: viewController)
  }
}
