import UIKit
import TKCore
import KeeperCore

struct TonConnectConfirmationAssembly {
  private init() {}
  static func module(model: ConfirmTransactionModel,
                     tonRatesStore: TonRatesStore,
                     currencyStore: CurrencyStore,
                     totalBalanceModel: WalletTotalBalanceModel,
                     decimalAmountFormatter: DecimalAmountFormatter,
                     historyEventMapper: HistoryEventMapper
  ) -> MVVMModule<TonConnectConfirmationViewController, TonConnectConfirmationModuleOutput, Void> {
    let viewModel = TonConnectConfirmationViewModelImplementation(
      model: model,
      tonRatesStore: tonRatesStore,
      currencyStore: currencyStore,
      totalBalanceModel: totalBalanceModel,
      decimalAmountFormatter: decimalAmountFormatter,
      historyEventMapper: historyEventMapper
    )
    let viewController = TonConnectConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
