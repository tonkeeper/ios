import UIKit
import TKCore
import KeeperCore

struct TonConnectConfirmationAssembly {
  private init() {}
  static func module(model: ConfirmTransactionModel,
                     keeperCoreMainAssembly: MainAssembly,
                     historyEventMapper: HistoryEventMapper
  ) -> MVVMModule<TonConnectConfirmationViewController, TonConnectConfirmationModuleOutput, Void> {
    let balanceModel = WalletTotalBalanceModel(
      walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
      totalBalanceStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate,
      balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
      updateQueue: .main
    )

    let viewModel = TonConnectConfirmationViewModelImplementation(
      model: model,
      tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      totalBalanceModel: balanceModel,
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      historyEventMapper: historyEventMapper
    )
    let viewController = TonConnectConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
