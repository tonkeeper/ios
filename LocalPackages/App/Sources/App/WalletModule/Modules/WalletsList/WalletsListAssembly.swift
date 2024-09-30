import Foundation
import TKCore
import KeeperCore

struct WalletsListAssembly {
  private init() {}
  static func module(model: WalletsListModel,
                     totalBalancesStore: TotalBalanceStore,
                     appSettingsStore: AppSettingsV3Store,
                     decimalAmountFormatter: DecimalAmountFormatter,
                     amountFormatter: AmountFormatter) -> MVVMModule<WalletsListViewController, WalletsListModuleOutput, Void> {
    let viewModel = WalletsListViewModelImplementation(
      model: model,
      totalBalancesStore: totalBalancesStore,
      appSettingsStore: appSettingsStore,
      decimalAmountFormatter: decimalAmountFormatter,
      amountFormatter: amountFormatter
    )
    
    let viewController = WalletsListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
