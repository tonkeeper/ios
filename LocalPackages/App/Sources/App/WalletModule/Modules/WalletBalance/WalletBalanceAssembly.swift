import Foundation
import TKCore
import KeeperCore

typealias WalletBalanceModule = MVVMModule<WalletBalanceViewController, WalletBalanceModuleOutput, WalletBalanceModuleInput>

struct WalletBalanceAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly, coreAssembly: TKCore.CoreAssembly) -> WalletBalanceModule {
    let viewModel = WalletBalanceViewModelImplementation(
      balanceListModel: WalletBalanceBalanceModel(
        walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
        balanceStore: keeperCoreMainAssembly.mainStoresAssembly.processedBalanceStore,
        stackingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
        tokenManagementStoreProvider: {
          keeperCoreMainAssembly.storesAssembly.tokenManagementStore(wallet: $0)
        },
        secureMode: coreAssembly.secureMode
      ),
      setupModel: WalletBalanceSetupModel(
        walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
        setupStore: keeperCoreMainAssembly.storesAssembly.setupStoreV2,
        securityStore: keeperCoreMainAssembly.storesAssembly.securityStoreV2,
        mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository()
      ),
      totalBalanceModel: WalletTotalBalanceModel(
        walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
        totalBalanceStore: keeperCoreMainAssembly.mainStoresAssembly.walletsTotalBalanceStore,
        secureMode: coreAssembly.secureMode,
        backgroundUpdateStore: keeperCoreMainAssembly.mainStoresAssembly.backgroundUpdateStoreV2
      ),
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
      notificationStore: keeperCoreMainAssembly.storesAssembly.notificationsStore,
      configurationStore: keeperCoreMainAssembly.configurationAssembly.remoteConfigurationStore,
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
      secureMode: coreAssembly.secureMode,
      urlOpener: coreAssembly.urlOpener()
    )
    let viewController = WalletBalanceViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
