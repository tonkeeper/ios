import Foundation
import TKCore
import KeeperCore

struct WalletsListAssembly {
  private init() {}
  static func module(model: WalletsListModel,
                     totalBalancesStore: WalletsTotalBalanceStoreV2,
                     amountFormatter: AmountFormatter) -> MVVMModule<WalletsListViewController, WalletsListModuleOutput, Void> {
    let viewModel = WalletsListViewModelImplementation(
      model: model,
      totalBalancesStore: totalBalancesStore,
      amountFormatter: amountFormatter
    )
    
    let viewController = WalletsListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
