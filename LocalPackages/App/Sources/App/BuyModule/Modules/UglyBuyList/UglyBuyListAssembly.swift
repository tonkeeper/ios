import UIKit
import TKCore
import KeeperCore

struct UglyBuyListAssembly {
  private init() {}
  static func module(buyListController: BuyListController,
                     appSettings: AppSettings) -> MVVMModule<UglyBuyListViewController, UglyBuyListModuleOutput, Void> {
    let viewModel = UglyBuyListViewModelImplementation(
      buyListController: buyListController,
      appSettings: appSettings
    )
    
    let viewController = UglyBuyListViewController(
      viewModel: viewModel
    )
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}


