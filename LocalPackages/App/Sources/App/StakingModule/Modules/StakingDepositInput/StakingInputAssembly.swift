import Foundation
import TKCore
import KeeperCore

struct StakingInputAssembly {
  private init() {}
  
  static func module(model: StakingInputModel, 
                     keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<StakingInputViewController, StakingInputModuleOutput, StakingInputModuleOutput> {
    let viewModel = StakingInputViewModelImplementation(
      model: model,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    
    let viewController = StakingInputViewController(viewModel: viewModel)
    
    return MVVMModule(view: viewController, output: viewModel, input: viewModel)
  }
}
