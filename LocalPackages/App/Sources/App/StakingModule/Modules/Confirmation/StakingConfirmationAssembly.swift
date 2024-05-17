import Foundation
import TKCore
import KeeperCore


struct StakingConfirmationAssembly {
  static func module(
    operation: StakingOperation,
    wallet: Wallet,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<StakingConfirmationViewController, StakingConfirmationModuleOutput, Void> {
    let viewModel = StakingConfirmationViewModelImplementation(
      controller: keeperCoreMainAssembly.stakingConfirmationController(wallet: wallet, operation: operation),
      modelMapper: .init()
    )
    let viewController = StakingConfirmationViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
