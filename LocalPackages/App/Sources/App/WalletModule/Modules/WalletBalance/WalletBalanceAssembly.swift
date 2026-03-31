import Foundation
import KeeperCore
import TKAppInfo
import TKCore
import UIKit

typealias WalletBalanceModule = MVVMModule<WalletBalanceViewController, WalletBalanceModuleOutput, WalletBalanceModuleInput>

struct WalletBalanceAssembly {
    private init() {}
    static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly, coreAssembly: TKCore.CoreAssembly) -> WalletBalanceModule {
        let queue = DispatchQueue(label: "WalletBalanceUpdateQueue")

        let balanceItemMapper = BalanceItemMapper(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        let stakingMappper = WalletBalanceListStakingMapper(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            balanceItemMapper: balanceItemMapper
        )
        let tooltips = TooltipsModule(
            dependencies: TooltipsModule.Dependencies(
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )
        )
        let withdrawTooltipService = WalletBalanceWithdrawTooltipServiceImplementation(
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            commonToolipsRepository: tooltips.commonDataRepository,
            withdrawTooltipRepository: tooltips.withdrawButtonRepository
        )
        let viewModel = WalletBalanceViewModelImplementation(
            balanceListModel: WalletBalanceBalanceModel(
                walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
                balanceStore: keeperCoreMainAssembly.storesAssembly.managedBalanceStore,
                stackingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
                appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
                configuration: keeperCoreMainAssembly.configurationAssembly.configuration
            ),
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            setupModel: WalletBalanceSetupModel(
                walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
                securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
                walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
                mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
                configuration: keeperCoreMainAssembly.configurationAssembly.configuration
            ),
            totalBalanceModel: WalletTotalBalanceModel(
                walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
                totalBalanceStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
                appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
                backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate,
                balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
                updateQueue: queue
            ),
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            notificationStore: keeperCoreMainAssembly.storesAssembly.internalNotificationsStore,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            listMapper:
            WalletBalanceListMapper(
                stakingMapper: stakingMappper,
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                balanceItemMapper: balanceItemMapper,
                rateConverter: RateConverter()
            ),
            headerMapper: WalletBalanceHeaderMapper(
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
            ),
            urlOpener: coreAssembly.urlOpener(),
            appSettings: coreAssembly.appSettings,
            storiesStore: keeperCoreMainAssembly.storesAssembly.storiesStore,
            withdrawTooltipService: withdrawTooltipService
        )
        let viewController = WalletBalanceViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
