import UIKit
import TKCore
import KeeperCore

struct StakePoolDetailsAssembly {
  private init() {}
  static func module(stakePoolDetailsController: StakePoolDetailsController,
                     stakePool: StakePool) -> MVVMModule<StakePoolDetailsViewController,StakePoolDetailsModuleOutput, StakePoolDetailsModuleInput> {
    let viewModel = StakePoolDetailsViewModelImplementation(
      stakePoolDetailsController: stakePoolDetailsController,
      stakePool: stakePool
    )
    
    let viewController = StakePoolDetailsViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
