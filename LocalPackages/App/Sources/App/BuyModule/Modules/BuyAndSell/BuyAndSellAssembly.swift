import UIKit
import TKCore
import KeeperCore

struct BuyAndSellAssembly {
  private init() {}
  static func module(buyListController: BuyListController,
                     appSettings: AppSettings,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<BuyAndSellViewController, BuyListModuleOutput, Void> {
    let viewModel = BuyListViewModelImplementation(
      buyListController: buyListController,
      appSettings: appSettings
    )
    
    let buyAndSellViewModel = BuyAndSellViewModelImplementation(buyListController: buyListController)
    
    let viewController = BuyAndSellViewController(viewModel: buyAndSellViewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
  
}
