import Foundation
import TKCore
import KeeperCore

struct StakingAmountAssembly {
    private init() {}
    static func module(
        stakingAmountController: StakingAmountController,
        stakingOptionsController: StakingOptionsController
    ) -> MVVMModule<StakingAmountViewController, StakingAmountModuleOutput, StakingAmountModuleInput> {
        let viewModel = StakingAmountViewModelImplementation(
            stakingAmountController: stakingAmountController,
            stakingOptionsController: stakingOptionsController
        )
        let viewController = StakingAmountViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
