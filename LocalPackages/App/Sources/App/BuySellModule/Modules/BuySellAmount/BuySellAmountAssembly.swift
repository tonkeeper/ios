import UIKit
import TKCore
import KeeperCore

struct BuySellAmountAssembly {
  private init() {}
  static func module(buySellAmountController: BuySellAmountController) -> MVVMModule<BuySellAmountViewController,
                                                                                     BuySellAmountModuleOutput,
                                                                                     BuySellAmountModuleInput> {
    let viewModel = BuySellAmountViewModelImplementation(
      buySellAmountController: buySellAmountController
    )
    
    let viewController = BuySellAmountViewController(
      viewModel: viewModel
    )
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
