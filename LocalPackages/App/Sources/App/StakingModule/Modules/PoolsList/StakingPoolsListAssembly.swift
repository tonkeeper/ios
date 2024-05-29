import Foundation
import TKCore
import KeeperCore

struct StakingPoolsListAssembly {
    private init() {}
    static func module(selectedPool: PoolImplementation, pool: PoolImplementation) -> MVVMModule<StakingPoolsListViewController, StakingPoolsListModuleOutput, StakingPoolsListModuleInput> {
        let viewModel = StakingPoolsListViewModelImplementation(selectedPool: selectedPool, pool: pool)
        let viewController = StakingPoolsListViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
