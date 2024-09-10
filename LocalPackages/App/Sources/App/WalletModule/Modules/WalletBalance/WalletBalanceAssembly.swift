import Foundation
import TKCore
import KeeperCore

typealias WalletBalanceModule = MVVMModule<WalletBalanceViewController, WalletBalanceModuleOutput, WalletBalanceModuleInput>

struct WalletBalanceAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly, coreAssembly: TKCore.CoreAssembly) -> WalletBalanceModule {
    let viewModel = WalletBalanceViewModelImplementation(
      balanceListModel: WalletBalanceBalanceModel(
        walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
        balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
        stackingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
        tokenManagementStore: keeperCoreMainAssembly.storesAssembly.tokenManagementStore,
        appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore
      ),
      setupModel: WalletBalanceSetupModel(
        walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
        appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
        securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
        walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
        mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository()
      ),
      totalBalanceModel: WalletTotalBalanceModel(
        walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
        totalBalanceStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
        appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
        backgroundUpdateStore: keeperCoreMainAssembly.storesAssembly.backgroundUpdateStore,
        stateLoader: keeperCoreMainAssembly.loadersAssembly.walletStateLoader
      ),
      walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
      notificationStore: keeperCoreMainAssembly.storesAssembly.internalNotificationsStore,
      configurationStore: keeperCoreMainAssembly.configurationAssembly.remoteConfigurationStore,
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      listMapper:
        WalletBalanceListMapper(
        amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
        balanceItemMapper: BalanceItemMapper(
          amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
          decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
        ),
        rateConverter: RateConverter()
      ),
      headerMapper: WalletBalanceHeaderMapper(
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
        dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
      ),
      urlOpener: coreAssembly.urlOpener()
    )
    let viewController = WalletBalanceViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
