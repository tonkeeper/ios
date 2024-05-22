import UIKit
import TKCore
import KeeperCore

struct OperatorSelectionAssembly {
  private init() {}
  static func module(
    settingsController: SettingsController,
    buyListController: BuyListController,
    decimalAmountFormatter: DecimalAmountFormatter,
    currencyStore: CurrencyStore,
    transactionModel: TransactionAmountModel
  ) -> MVVMModule<OperatorSelectionViewController, OperatorSelectionViewModelOutput, Void> {
    
    let viewModel = OperatorSelectionViewModelImplementation(
      settingsController: settingsController,
      buyListController: buyListController,
      currencyStore: currencyStore,
      decimalAmountFormatter: decimalAmountFormatter
    )
    
    let viewController = OperatorSelectionViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
  
}
