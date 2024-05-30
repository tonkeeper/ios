import UIKit
import TKCore
import KeeperCore

struct CurrencyListAssembly {
  private init() {}
  static func module(currencyListController: CurrencyListController,
                     currencyListItem: CurrencyListItem) -> MVVMModule<CurrencyListViewController, CurrencyListModuleOutput, Void> {
    let viewModel = CurrencyListViewModelImplementation(
      currencyListController: currencyListController,
      currencyListItem: currencyListItem
    )
    
    let viewController = CurrencyListViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}
