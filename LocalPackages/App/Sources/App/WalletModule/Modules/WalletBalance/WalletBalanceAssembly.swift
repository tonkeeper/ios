import Foundation
import TKCore
import KeeperCore

typealias WalletBalanceModule = MVVMModule<WalletBalanceViewController, WalletBalanceModuleOutput, WalletBalanceModuleInput>

struct WalletBalanceAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly) -> WalletBalanceModule {
    let viewModel = WalletBalanceViewModelImplementation(
      balanceListModel: WalletBalanceBalanceModel(
        walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStoreV2,
        convertedBalanceStore: keeperCoreMainAssembly.mainStoresAssembly.convertedBalanceStore
      ),
      setupModel: WalletBalanceSetupModel(
        walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStoreV2,
        setupStore: keeperCoreMainAssembly.storesAssembly.setupStoreV2,
        securityStore: keeperCoreMainAssembly.storesAssembly.securityStoreV2
      ),
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStoreV2,
      totalBalanceStore: keeperCoreMainAssembly.mainStoresAssembly.walletsTotalBalanceStore,
      listMapper:
        WalletBalanceListMapper(
        amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
        rateConverter: RateConverter()
      ),
      headerMapper: WalletBalanceHeaderMapper(
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
      )
    )
    let viewController = WalletBalanceViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
