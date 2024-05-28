import UIKit
import TKCore
import KeeperCore

struct BuyAndSellAssembly {
  private init() {}
  static func module(
    buyListController: BuyListController,
    currencyStore: CurrencyStore,
    bigIntAmountFormatter: BigIntAmountFormatter
  ) -> MVVMModule<BuyAndSellViewController, BuyAndSellViewModelOutput, Void> {
    let viewModel = BuyAndSellViewModelImplementation(
      buyListController: buyListController,
      currencyStore: currencyStore,
      bigIntAmountFormatter: bigIntAmountFormatter
    )
    
    let viewController = BuyAndSellViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
  
}
