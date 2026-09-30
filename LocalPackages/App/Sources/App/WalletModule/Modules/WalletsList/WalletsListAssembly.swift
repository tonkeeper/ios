import Foundation
import KeeperCore
import TKCore

struct WalletsListAssembly {
    private init() {}
    @MainActor
    static func module(
        model: WalletsListModel,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        raffleStore: RaffleStore? = nil,
        analyticsProvider: AnalyticsProvider? = nil,
        tooltipsService: TooltipsService? = nil,
        shouldShowAddMultichainWalletTooltip: Bool = false
    ) -> MVVMModule<WalletsListViewController, WalletsListModuleOutput, Void> {
        let viewModel = WalletsListViewModelImplementation(
            model: model,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            totalBalancesStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
            multichainPortfolioStore: keeperCoreMainAssembly.storesAssembly.multichainPortfolioStore,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            homeBannersStore: keeperCoreMainAssembly.storesAssembly.homeBannersStore,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            raffleStore: raffleStore,
            analyticsProvider: analyticsProvider
        )

        let viewController = WalletsListViewController(
            viewModel: viewModel,
            tooltipsService: tooltipsService,
            shouldShowAddMultichainWalletTooltip: shouldShowAddMultichainWalletTooltip
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
