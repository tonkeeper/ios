import Foundation
import KeeperCore
import TKAppInfo
import TKCore
import UIKit

typealias WalletBalanceModule = MVVMModule<WalletBalanceViewController, WalletBalanceModuleOutput, WalletBalanceModuleInput>

struct WalletBalanceAssembly {
    private init() {}
    @MainActor
    static func module(
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> WalletBalanceModule {
        let queue = DispatchQueue(label: "WalletBalanceUpdateQueue")

        let balanceItemMapper = BalanceItemMapper(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        let stakingMappper = WalletBalanceListStakingMapper(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            balanceItemMapper: balanceItemMapper
        )
        let tradeAssetDetailsValueFormatter = TradeAssetDetailsValueFormatter(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            signedAmountFormatter: keeperCoreMainAssembly.formattersAssembly.signedAmountFormatter,
            currencyProvider: { keeperCoreMainAssembly.storesAssembly.currencyStore.state }
        )
        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
        let storesAssembly = keeperCoreMainAssembly.storesAssembly

        let pushAuthorizationModel = PushAuthorizationModel()

        let viewModel = WalletBalanceViewModelImplementation(
            wallet: wallet,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            walletsStore: storesAssembly.walletsStore,
            notificationStore: storesAssembly.internalNotificationsStore,
            configuration: configuration,
            appSettingsStore: storesAssembly.appSettingsStore,
            listMapper:
            WalletBalanceListMapper(
                stakingMapper: stakingMappper,
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                balanceItemMapper: balanceItemMapper,
                rateConverter: RateConverter(),
                tonStakingAPYProvider: { [keeperCoreMainAssembly] wallet in
                    let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
                    guard !configuration.flag(\.stakingDisabled, network: wallet.network) else {
                        return nil
                    }

                    return keeperCoreMainAssembly.storesAssembly.stackingPoolsStore.state[wallet]?
                        .filter { configuration.value(\.stakingEnabledProviders).contains($0.implementation.type.rawValue) }
                        .map(\.apy)
                        .max()
                },
                tonStakingAPYTextFormatter: { value in
                    tradeAssetDetailsValueFormatter.earnApyValueFormatter(value)
                }
            ),
            urlOpener: coreAssembly.urlOpener(),
            makeWalletViewModel: { wallet in
                Self.walletViewModel(
                    wallet: wallet,
                    queue: queue,
                    configuration: configuration,
                    keeperCoreMainAssembly: keeperCoreMainAssembly,
                    coreAssembly: coreAssembly,
                    pushAuthorizationModel: pushAuthorizationModel
                )
            }
        )
        let viewController = WalletBalanceViewController(
            viewModel: viewModel,
            tooltipsService: coreAssembly.tooltipsAssembly.service
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }

    @MainActor
    private static func walletViewModel(
        wallet: Wallet,
        queue: DispatchQueue,
        configuration: Configuration,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        pushAuthorizationModel: PushAuthorizationModel
    ) -> WalletBalanceWalletViewModel {
        let storesAssembly = keeperCoreMainAssembly.storesAssembly

        let headerViewModel = WalletBalanceHeaderViewModel(
            wallet: wallet,
            totalBalanceModel: WalletTotalBalanceModel(
                wallet: wallet,
                totalBalanceStore: storesAssembly.totalBalanceStore,
                appSettingsStore: storesAssembly.appSettingsStore,
                backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate,
                balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
                updateQueue: queue
            ),
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            walletsStore: storesAssembly.walletsStore,
            appSettingsStore: storesAssembly.appSettingsStore,
            appSettings: coreAssembly.appSettings,
            headerMapper: WalletBalanceHeaderMapper(
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
                dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
            ),
            configuration: configuration,
            tooltipsService: coreAssembly.tooltipsAssembly.service
        )

        let homeBannersViewModel = WalletBalanceHomeBannersViewModel(
            wallet: wallet,
            walletsStore: storesAssembly.walletsStore,
            homeBannersStore: storesAssembly.homeBannersStore,
            homeBannersLoader: keeperCoreMainAssembly.loadersAssembly.homeBannersLoader,
            deeplinkParser: keeperCoreMainAssembly.deeplinkParser,
            analyticsProvider: coreAssembly.analyticsProvider
        )
        homeBannersViewModel.onOpenLink = { url in
            coreAssembly.urlOpener().open(url: url)
        }

        return WalletBalanceWalletViewModel(
            balanceListModel: WalletBalanceBalanceModel(
                wallet: wallet,
                walletsStore: storesAssembly.walletsStore,
                balanceStore: storesAssembly.managedBalanceStore,
                stackingPoolsStore: storesAssembly.stackingPoolsStore,
                appSettingsStore: storesAssembly.appSettingsStore,
                configuration: configuration
            ),
            setupModel: WalletBalanceSetupModel(
                wallet: wallet,
                walletsStore: storesAssembly.walletsStore,
                processedBalanceStore: storesAssembly.processedBalanceStore,
                securityStore: storesAssembly.securityStore,
                walletNotificationStore: storesAssembly.walletNotificationStore,
                mnemonicsAccess: keeperCoreMainAssembly.secureAssembly.mnemonicAccess,
                configuration: configuration,
                pushAuthorizationModel: pushAuthorizationModel
            ),
            headerViewModel: headerViewModel,
            homeBannersViewModel: homeBannersViewModel,
            collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel(
                wallet: wallet,
                storesAssembly: storesAssembly,
                accountNftService: keeperCoreMainAssembly.servicesAssembly.accountNftService(),
                appSettingsStore: storesAssembly.appSettingsStore
            )
        )
    }
}
