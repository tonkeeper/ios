import UIKit
import TKCore
import KeeperCore

struct BuySellDetailsAssembly {
  private init() {}
  static func module(buySellDetailsController: BuySellDetailsController,
                     buySellTransactionModel: BuySellTransactionModel,
                     buySellDetailsItem: BuySellDetailsItem) -> MVVMModule<BuySellDetailsViewController, BuySellDetailsModuleOutput, Void> {
    let viewModel = BuySellDetailsViewModelImplementation(
      buySellDetailsController: buySellDetailsController,
      buySellTransactionModel: buySellTransactionModel,
      buySellDetailsItem: buySellDetailsItem
    )
    
    let viewController = BuySellDetailsViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}
