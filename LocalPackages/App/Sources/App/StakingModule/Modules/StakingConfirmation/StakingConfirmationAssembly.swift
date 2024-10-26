import Foundation
import TKCore
import KeeperCore

struct StakingConfirmationAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     stakingConfirmationController: StakeConfirmationController) -> MVVMModule<StakingConfirmationViewController, StakingConfirmationModuleOutput, StakingConfirmationModuleInput> {
    let viewModel = StakingConfirmationViewModelImplementation(
      wallet: wallet,
      stakingConfirmationController: stakingConfirmationController
    )
    let viewController = StakingConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
