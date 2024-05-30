import UIKit
import TKCore
import KeeperCore

struct StakeOptionsAssembly {
  private init() {}
  static func module(stakeOptionsController: StakeOptionsController,
                     selectedStakePool: StakePool) -> MVVMModule<StakeOptionsViewController, StakeOptionsModuleOutput, StakeOptionsModuleInput> {
    let viewModel = StakeOptionsViewModelImplementation(
      stakeOptionsController: stakeOptionsController,
      selectedStakePool: selectedStakePool
    )
    
    let viewController = StakeOptionsViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
