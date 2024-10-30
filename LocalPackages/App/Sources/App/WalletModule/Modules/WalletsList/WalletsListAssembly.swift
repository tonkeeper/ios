import Foundation
import TKCore
import KeeperCore

struct WalletsListAssembly {
  private init() {}
  static func module(model: WalletsListModel,
                     balanceLoader: BalanceLoader,
                     totalBalancesStore: TotalBalanceStore,
                     appSettingsStore: AppSettingsStore,
                     decimalAmountFormatter: DecimalAmountFormatter,
                     amountFormatter: AmountFormatter) -> MVVMModule<WalletsListViewController, WalletsListModuleOutput, Void> {
    let viewModel = WalletsListViewModelImplementation(
      model: model,
      balanceLoader: balanceLoader,
      totalBalancesStore: totalBalancesStore,
      appSettingsStore: appSettingsStore,
      decimalAmountFormatter: decimalAmountFormatter,
      amountFormatter: amountFormatter
    )
    
    let viewController = WalletsListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
