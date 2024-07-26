import UIKit
import TKCore
import KeeperCore

struct StakingInputAssembly {
  private init() {}
  
  static func module(model: StakingInputModel,
                     detailsViewController: UIViewController,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<StakingInputViewController, StakingInputModuleOutput, StakingInputModuleInput> {
    let viewModel = StakingInputViewModelImplementation(
      model: model,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    
    let viewController = StakingInputViewController(
      viewModel: viewModel,
      detailsViewController: detailsViewController
    )
    
    return MVVMModule(view: viewController, output: viewModel, input: viewModel)
  }
}
