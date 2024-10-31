import UIKit
import TKCore
import KeeperCore

struct TonConnectConfirmationAssembly {
  private init() {}
  static func module(model: ConfirmTransactionModel,
                     keeperCoreMainAssembly: MainAssembly,
                     historyEventMapper: HistoryEventMapper
  ) -> MVVMModule<TonConnectConfirmationViewController, TonConnectConfirmationModuleOutput, Void> {
    let viewModel = TonConnectConfirmationViewModelImplementation(
      model: model,
      tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      totalBalanceStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      historyEventMapper: historyEventMapper
    )
    let viewController = TonConnectConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
