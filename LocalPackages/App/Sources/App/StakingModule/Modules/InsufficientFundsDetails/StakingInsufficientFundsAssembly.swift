import Foundation
import TKCore
import KeeperCore

struct StakingInsufficientFundsAssembly {
  static func module(
    fundsModel: StakingTransactionSendingStatus.InsufficientFunds,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<StakingInsufficientFundsViewController, StakingInsufficientFundsViewModuleOutput, Void> {
    let viewModel = StakingInsufficientFundsViewModelImplementation(
      fundsModel: fundsModel,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    let viewController = StakingInsufficientFundsViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
