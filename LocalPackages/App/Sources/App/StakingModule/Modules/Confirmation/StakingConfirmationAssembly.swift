import Foundation
import TKCore
import KeeperCore

struct StakingConfirmationAssembly {
  static func module(
    stakeConfirmationItem: StakingConfirmationItem,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<StakingConfirmationViewController, StakingConfirmationModuleOutput, Void> {
    let controller = makeController(keeperCoreAssembly: keeperCoreMainAssembly, confirmationItem: stakeConfirmationItem)
    
    let viewModel = StakingConfirmationViewModelImplementation(controller: controller, modelMapper: .init())
    let viewController = StakingConfirmationViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: Void())
  }
  
  private static func makeController(
    keeperCoreAssembly: KeeperCore.MainAssembly,
    confirmationItem: StakingConfirmationItem
  ) -> StakingConfirmationController {
    let amount = confirmationItem.amount
    switch confirmationItem.operatiom {
    case .deposit(let pool):
      return keeperCoreAssembly.stakingConfirmationController(
        stakingPool: pool,
        amount: amount,
        isMax: confirmationItem.isMax
      )
    case .withdraw(let pool):
      return keeperCoreAssembly.stakingWithdrawConfirmationController(
        stakingPool: pool,
        amount: amount,
        isMax: confirmationItem.isMax
      )
    }
  }
}
