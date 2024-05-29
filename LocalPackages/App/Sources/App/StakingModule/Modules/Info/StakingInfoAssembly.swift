import Foundation
import TKCore
import KeeperCore

struct StakingInfoAssembly {
    static func module(pool: PoolImplementation) -> MVVMModule<StakingInfoViewController, StakingInfoModuleOutput, StakingInfoModuleInput> {
        let viewModel = StakingInfoViewModelImplementation(pool: pool)
        let viewController = StakingInfoViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
