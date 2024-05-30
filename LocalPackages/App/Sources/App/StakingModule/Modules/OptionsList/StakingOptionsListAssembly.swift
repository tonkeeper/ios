import Foundation
import TKCore
import KeeperCore

struct StakingOptionsListAssembly {
    private init() {}
    static func module(
        stakingOptionsController: StakingOptionsController,
        selectedPool: PoolImplementation
    ) -> MVVMModule<StakingOptionsListViewController, StakingOptionsListModuleOutput, Void> {
        let viewModel = StakingOptionsListViewModelImplementation(
            stakingOptionsController: stakingOptionsController,
            selectedPool: selectedPool
        )
        let viewController = StakingOptionsListViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
