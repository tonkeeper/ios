import Foundation
import TKCore
import KeeperCore

struct StakingDepositInputPoolPickerAssembly {
  private init() {}
  
  static func module(wallet: Wallet, keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<StakingDepositInputPoolPickerViewController, Void, StakingInputDetailsModuleInput> {
    let viewController = StakingDepositInputPoolPickerViewController(
      wallet: wallet,
      stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    
    return MVVMModule(view: viewController, output: Void(), input: viewController)
  }
}
