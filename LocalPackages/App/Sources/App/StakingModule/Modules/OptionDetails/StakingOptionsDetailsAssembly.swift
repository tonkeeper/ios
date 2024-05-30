import Foundation
import TKCore
import KeeperCore

struct StakingOptionDetailsAssembly {
  private init() {}
  
  static func module(
    stakingPool: StakingPool,
    keeperCoreMainAssembly: KeeperCore.MainAssembly,
    urlOpener: URLOpener
  ) -> MVVMModule<StakingOptionDetailsViewController, StakingOptionDetailsModuleOutput, Void> {
    let viewModel = StakingOptionDetailsViewModelImplementation(
      controller: keeperCoreMainAssembly.stakingOptionDetailsController(stakingPool: stakingPool),
      urlOpener: urlOpener
    )
    let viewController = StakingOptionDetailsViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
