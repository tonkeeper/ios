import Foundation
import TKCore
import KeeperCore

struct StakingDepositEditAmountAssembly {
  private init() {}
  
  static func module(
    depositModel: DepositModel,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<StakingEditAmountViewController, StakingEditAmountModuleOutput, StakingEditAmountModuleInput> {
    let viewModel = StakingEditAmountViewModelImplementation(
      controller: keeperCoreMainAssembly.stakingDepositEditAmountController(depositModel: depositModel),
      itemMapper: .init()
    )
    let viewController = StakingEditAmountViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
