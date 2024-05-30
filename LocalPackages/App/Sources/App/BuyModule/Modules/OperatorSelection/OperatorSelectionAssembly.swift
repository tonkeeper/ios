import UIKit
import TKCore
import KeeperCore

struct OperatorSelectionAssembly {
  private init() {}
  static func module(
    settingsController: SettingsController,
    buyListController: BuyListController,
    currencyRateFormatter: CurrencyToTONFormatter,
    currencyStore: CurrencyStore,
    transactionModel: TransactionAmountModel
  ) -> MVVMModule<OperatorSelectionViewController, OperatorSelectionViewModelOutput, Void> {
    
    let viewModel = OperatorSelectionViewModelImplementation(
      settingsController: settingsController,
      buyListController: buyListController,
      currencyStore: currencyStore,
      currencyRateFormatter: currencyRateFormatter,
      transactionModel: transactionModel
    )
    
    let viewController = OperatorSelectionViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}
