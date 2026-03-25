import Foundation
import KeeperCore
import TKCore

struct EthenaStakingDetailsAssembly {
    private init() {}

    static func module(
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    )
        -> MVVMModule<EthenaStakingDetailsViewController, EthenaStakingDetailsModuleOutput, EthenaStakingDetailsModuleOutput>
    {
        let viewModel = EthenaStakingDetailsViewModelImplementation(
            wallet: wallet,
            ethenaStakingLoader: keeperCoreMainAssembly.loadersAssembly.ethenaStakingLoader(wallet: wallet),
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
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        let viewController = EthenaStakingDetailsViewController(viewModel: viewModel)

        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}
