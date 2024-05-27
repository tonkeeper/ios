import UIKit
import TKCore
import KeeperCore

struct StakeAssembly {
  private init() {}
  static func module(stakeController: StakeController) -> MVVMModule<StakeViewController, StakeModuleOutput, StakeModuleInput> {
    let viewModel = StakeViewModelImplementation(
      stakeController: stakeController
    )
    
    let viewController = StakeViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
