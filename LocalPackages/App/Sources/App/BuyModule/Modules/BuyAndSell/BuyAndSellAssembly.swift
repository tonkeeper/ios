import UIKit
import TKCore
import KeeperCore

struct BuyAndSellAssembly {
  private init() {}
  static func module(buyListController: BuyListController,
                     appSettings: AppSettings) -> MVVMModule<BuyAndSellViewController, BuyListModuleOutput, Void> {
    let viewModel = BuyListViewModelImplementation(
      buyListController: buyListController,
      appSettings: appSettings
    )
    
    let viewController = BuyAndSellViewController()
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}
