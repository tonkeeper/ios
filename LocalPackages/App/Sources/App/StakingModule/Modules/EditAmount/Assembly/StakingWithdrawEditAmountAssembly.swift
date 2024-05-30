import Foundation
import TKCore
import KeeperCore

public struct StakingWithdrawEditAmountAssembly {
  private init() {}
  
  static func module(
    stakingPool: StakingPool,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<StakingEditAmountViewController, StakingEditAmountModuleOutput, StakingEditAmountModuleInput> {
    let viewModel = StakingEditAmountViewModelImplementation(
      controller: keeperCoreMainAssembly.stakingWithdrawEditAmountController(stakingPool: stakingPool),
      itemMapper: .init()
    )
    let viewController = StakingEditAmountViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
