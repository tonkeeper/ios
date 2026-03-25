import Foundation
import KeeperCore
import TKCore

struct StakingBalanceDetailsAssembly {
    private init() {}

    static func module(
        wallet: Wallet,
        stakingPoolInfo: StackingPoolInfo,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    )
        -> MVVMModule<StakingBalanceDetailsViewController, StakingBalanceDetailsModuleOutput, StakingBalanceDetailsModuleOutput>
    {
        let viewModel = StakingBalanceDetailsViewModelImplementation(
            wallet: wallet,
            stakingPoolInfo: stakingPoolInfo,
            listViewModelBuilder: StakingListViewModelBuilder(
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
            ),
            linksViewModelBuilder: StakingLinksViewModelBuilder(),
            balanceItemMapper: BalanceItemMapper(
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
            ),
            stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
            balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )

        let viewController = StakingBalanceDetailsViewController(viewModel: viewModel)

        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}
