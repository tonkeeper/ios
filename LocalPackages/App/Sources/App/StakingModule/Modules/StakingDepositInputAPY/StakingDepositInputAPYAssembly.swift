import Foundation
import TKCore
import KeeperCore

struct StakingDepositInputAPYAssembly {
  private init() {}
  
  static func module(wallet: Wallet, keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<StakingDepositInputAPYViewController, Void, StakingInputDetailsModuleInput> {
    let viewController = StakingDepositInputAPYViewController(
      wallet: wallet,
      balanceStore: keeperCoreMainAssembly.mainStoresAssembly.convertedBalanceStore,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
    )
    
    return MVVMModule(view: viewController, output: Void(), input: viewController)
  }
}
