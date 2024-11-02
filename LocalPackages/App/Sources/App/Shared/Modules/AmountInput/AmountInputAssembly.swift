import UIKit
import TKCore
import KeeperCore

struct AmountInputAssembly {
  private init() {}
  static func module(
    sourceUnit: AmountInputUnit,
    destinationUnit: AmountInputUnit,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<AmountInputViewController, AmountInputModuleOutput, AmountInputModuleInput> {
    let viewModel = AmountInputViewModelImplementation(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      sourceUnit: sourceUnit,
      destinationUnit: destinationUnit
    )
    let viewController = AmountInputViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
