import Foundation
import KeeperCore
import TKCore

struct StakingPoolDetailsAssembly {
    private init() {}

    static func module(
        pool: StakingListPool,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    )
        -> MVVMModule<StakingPoolDetailsViewController, StakingPoolDetailsModuleOutput, StakingPoolDetailsModuleOutput>
    {
        let viewModel = StakingPoolDetailsViewModelImplementation(
            pool: pool,
            listViewModelBuilder: StakingListViewModelBuilder(
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
            ),
            linksViewModelBuilder: StakingLinksViewModelBuilder()
        )

        let viewController = StakingPoolDetailsViewController(viewModel: viewModel)

        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}
