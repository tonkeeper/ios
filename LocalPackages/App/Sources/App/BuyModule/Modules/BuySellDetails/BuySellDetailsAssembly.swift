import UIKit
import TKCore
import KeeperCore

struct BuySellDetailsAssembly {
  private init() {}
  static func module(buySellDetailsController: BuySellDetailsController,
                     buySellDetailsItem: BuySellDetailsItem,
                     buySellTransactionModel: BuySellTransactionModel) -> MVVMModule<BuySellDetailsViewController, BuySellDetailsModuleOutput, Void> {
    let viewModel = BuySellDetailsViewModelImplementation(
      buySellDetailsController: buySellDetailsController,
      buySellDetailsItem: buySellDetailsItem,
      buySellTransactionModel: buySellTransactionModel
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
