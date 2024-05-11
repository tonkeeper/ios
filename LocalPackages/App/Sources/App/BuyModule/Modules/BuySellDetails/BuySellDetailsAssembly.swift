import UIKit
import TKCore
import KeeperCore

struct BuySellDetailsAssembly {
  private init() {}
  static func module(buySellDetailsController: BuySellDetailsController,
                     buySellDetailsItem: BuySellDetailsItem) -> MVVMModule<BuySellDetailsViewController, BuySellDetailsModuleOutput, BuySellDetailsModuleInput> {
    let viewModel = BuySellDetailsViewModelImplementation(
      buySellDetailsController: buySellDetailsController,
      buySellDetailsItem: buySellDetailsItem
    )
    
    let viewController = BuySellDetailsViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
