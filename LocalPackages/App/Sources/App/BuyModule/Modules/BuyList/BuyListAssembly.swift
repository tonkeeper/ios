import UIKit
import TKCore
import KeeperCore

struct BuyListAssembly {
  private init() {}
  static func module(buyListController: BuyListController) -> MVVMModule<BuyListViewController, BuyListModuleOutput, Void> {
    let viewModel = BuyListViewModelImplementation(
      buyListController: buyListController
    )
    
    let viewController = BuyListViewController(
      viewModel: viewModel
    )
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}


