import Foundation
import TKCore
import KeeperCore

struct StakingAssembly {
  private init() {}
  
  static func module(
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<StakingViewController, StakingModuleOutput, StakingModuleInput> {
    let viewModel = StakingViewModelImplementation(
      controller: keeperCoreMainAssembly.stakingController()
    )
    let viewController = StakingViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
