import UIKit
import TKCore
import KeeperCore

struct BuyAndSellAssembly {
  private init() {}
  static func module(
    buyListController: BuyListController,
    tonRatesStore: TonRatesStore,
    bigIntAmountFormatter: BigIntAmountFormatter
  ) -> MVVMModule<BuyAndSellViewController, BuyAndSellViewModelOutput, Void> {
    let viewModel = BuyAndSellViewModelImplementation(
      buyListController: buyListController,
      tonRatesStore: tonRatesStore,
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
