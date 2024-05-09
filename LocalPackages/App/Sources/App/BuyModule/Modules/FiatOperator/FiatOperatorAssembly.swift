import UIKit
import TKCore
import KeeperCore

struct FiatOperatorAssembly {
  private init() {}
  static func module(fiatOperatorController: FiatOperatorController,
                     buySellOperation: BuySellOperationModel) -> MVVMModule<FiatOperatorViewController, FiatOperatorModuleOutput, FiatOperatorModuleInput> {
    let viewModel = FiatOperatorViewModelImplementation(
      fiatOperatorController: fiatOperatorController,
      buySellOperation: buySellOperation
    )
    
    let viewController = FiatOperatorViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
