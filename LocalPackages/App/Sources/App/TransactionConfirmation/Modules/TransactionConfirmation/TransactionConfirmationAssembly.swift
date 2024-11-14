import Foundation
import TKCore
import KeeperCore

@MainActor
struct TransactionConfirmationAssembly {
  private init() {}
  static func module(
    transactionConfirmationController: TransactionConfirmationController,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<TransactionConfirmationViewController, TransactionConfirmationOutput, Void> {
    let viewModel = TransactionConfirmationViewModelImplementation(
      confirmationController: transactionConfirmationController,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      decimalFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
    )
    let viewController = TransactionConfirmationViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
