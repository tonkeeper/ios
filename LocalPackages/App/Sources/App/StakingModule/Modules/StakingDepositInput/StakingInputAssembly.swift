import UIKit
import TKCore
import KeeperCore

struct StakingInputAssembly {
  private init() {}
  
  static func module(model: StakingInputModel,
                     detailsViewController: UIViewController,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly)
  -> MVVMModule<StakingInputViewController, StakingInputModuleOutput, StakingInputModuleInput> {
    let viewModel = StakingInputViewModelImplementation(
      model: model,
      configurationStore: keeperCoreMainAssembly.configurationAssembly.configurationStore,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      urlOpener: coreAssembly.urlOpener()
    )
    
    let viewController = StakingInputViewController(
      viewModel: viewModel,
      detailsViewController: detailsViewController
    )
    
    return MVVMModule(view: viewController, output: viewModel, input: viewModel)
  }
}
