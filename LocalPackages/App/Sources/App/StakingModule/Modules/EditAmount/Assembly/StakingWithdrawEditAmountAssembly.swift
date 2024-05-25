import Foundation
import TKCore
import KeeperCore

public struct StakingWithdrawEditAmountAssembly {
  private init() {}
  
  static func module(
    withdrawModel: WithdrawModel,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<StakingEditAmountViewController, StakingEditAmountModuleOutput, StakingEditAmountModuleInput> {
    let viewModel = StakingEditAmountViewModelImplementation(
      controller: keeperCoreMainAssembly.stakingWithdrawEditAmountController(withdrawModel: withdrawModel),
      itemMapper: .init()
    )
    let viewController = StakingEditAmountViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
