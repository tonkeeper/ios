import UIKit
import TKCore
import KeeperCore

struct BuySellOperatorAssembly {
  private init() {}
  static func module(buySellOperatorController: BuySellOperatorController,
                     buySellOperation: BuySellOperationModel) -> MVVMModule<BuySellOperatorViewController, BuySellOperatorModuleOutput, BuySellOperatorModuleInput> {
    let viewModel = BuySellOperatorViewModelImplementation(
      buySellOperatorController: buySellOperatorController,
      buySellOperation: buySellOperation
    )
    
    let viewController = BuySellOperatorViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
