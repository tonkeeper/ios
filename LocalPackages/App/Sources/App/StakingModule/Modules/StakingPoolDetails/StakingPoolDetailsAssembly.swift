import Foundation
import TKCore
import KeeperCore

struct StakingPoolDetailsAssembly {
  private init() {}
  
  static func module(pool: StakingListPool, 
                     keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<StakingPoolDetailsViewController, StakingPoolDetailsModuleOutput, StakingPoolDetailsModuleOutput> {
    let viewModel = StakingPoolDetailsViewModelImplementation(
      pool: pool,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    
    let viewController = StakingPoolDetailsViewController(viewModel: viewModel)
    
    return MVVMModule(view: viewController, output: viewModel, input: viewModel)
  }
}
