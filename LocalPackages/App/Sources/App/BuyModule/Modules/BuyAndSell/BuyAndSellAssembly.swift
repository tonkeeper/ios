import UIKit
import TKCore
import KeeperCore

struct BuyAndSellAssembly {
  private init() {}
  static func module(buyListController: BuyListController) -> MVVMModule<BuyAndSellViewController, BuyAndSellViewModelOutput, Void> {
    let viewModel = BuyAndSellViewModelImplementation(buyListController: buyListController)
    
    let viewController = BuyAndSellViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
  
}
