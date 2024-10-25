import Foundation
import TKCore
import KeeperCore

typealias WalletBalanceModule = MVVMModule<WalletBalanceViewController, WalletBalanceModuleOutput, WalletBalanceModuleInput>

struct WalletBalanceAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly, coreAssembly: TKCore.CoreAssembly) -> WalletBalanceModule {
    
    let balanceItemMapper = BalanceItemMapper(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
    )
    
    let stakingMappper = WalletBalanceListStakingMapper(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
      balanceItemMapper: balanceItemMapper
    )
    
    let viewModel = WalletBalanceViewModelImplementation(
      balanceListModel: WalletBalanceBalanceModel(
        walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
        balanceStore: keeperCoreMainAssembly.storesAssembly.managedBalanceStore,
        stackingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
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
      configurationStore: keeperCoreMainAssembly.configurationAssembly.configurationStore,
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      listMapper:
        WalletBalanceListMapper(
          stakingMapper: stakingMappper,
          amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
          balanceItemMapper: balanceItemMapper,
          rateConverter: RateConverter()
        ),
      headerMapper: WalletBalanceHeaderMapper(
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
        dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
      ),
      urlOpener: coreAssembly.urlOpener(),
      appSettings: coreAssembly.appSettings
    )
    let viewController = WalletBalanceViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
