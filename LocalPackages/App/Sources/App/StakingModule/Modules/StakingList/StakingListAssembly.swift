import Foundation
import KeeperCore
import TKCore

struct StakingListAssembly {
    private init() {}

    static func module(
        model: StakingListModel,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    )
        -> MVVMModule<StakingListViewController, StakingListModuleOutput, Void>
    {
        let viewModel = StakingListViewModelImplementation(
            model: model,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        let viewController = StakingListViewController(viewModel: viewModel)

        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}
