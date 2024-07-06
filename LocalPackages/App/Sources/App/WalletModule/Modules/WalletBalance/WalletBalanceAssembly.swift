import Foundation
import TKCore
import KeeperCore

typealias WalletBalanceModule = MVVMModule<WalletBalanceViewController, WalletBalanceModuleOutput, WalletBalanceModuleInput>

struct WalletBalanceAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly, coreAssembly: TKCore.CoreAssembly) -> WalletBalanceModule {
    let viewModel = WalletBalanceViewModelImplementation(
      balanceListModel: WalletBalanceBalanceModel(
        walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStoreV2,
        convertedBalanceStore: keeperCoreMainAssembly.mainStoresAssembly.convertedBalanceStore,
        stackingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
        secureMode: coreAssembly.secureMode
      ),
      setupModel: WalletBalanceSetupModel(
        walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStoreV2,
        setupStore: keeperCoreMainAssembly.storesAssembly.setupStoreV2,
        securityStore: keeperCoreMainAssembly.storesAssembly.securityStoreV2
      ),
      totalBalanceModel: WalletTotalBalanceModel(
        walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStoreV2,
        totalBalanceStore: keeperCoreMainAssembly.mainStoresAssembly.walletsTotalBalanceStore,
        secureMode: coreAssembly.secureMode
      ),
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStoreV2,
      notificationStore: keeperCoreMainAssembly.storesAssembly.notificationsStore,
      configurationStore: keeperCoreMainAssembly.configurationAssembly.remoteConfigurationStore,
      listMapper:
        WalletBalanceListMapper(
        amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
        rateConverter: RateConverter()
      ),
      headerMapper: WalletBalanceHeaderMapper(
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
      ),
      secureMode: coreAssembly.secureMode,
      urlOpener: coreAssembly.urlOpener()
    )
    let viewController = WalletBalanceViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
