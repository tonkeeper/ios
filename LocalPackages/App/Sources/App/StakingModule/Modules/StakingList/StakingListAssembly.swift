import Foundation
import TKCore
import KeeperCore

struct StakingListAssembly {
  private init() {}
  
  static func module(model: StakingListModel,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<StakingListViewController, StakingListModuleOutput, Void> {
    let viewModel = StakingListViewModelImplementation(
      model: model,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
      
    let viewController = StakingListViewController(viewModel: viewModel)
    
    return MVVMModule(view: viewController, output: viewModel, input: Void())
  }
}
