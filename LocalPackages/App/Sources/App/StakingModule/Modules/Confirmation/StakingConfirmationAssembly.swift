import Foundation
import TKCore
import KeeperCore
import BigInt

struct StakingConfirmationAssembly {
    static func module(
        stakingModel: StakingModel,
        sendConfirmationController: SendConfirmationController
    ) -> MVVMModule<StakingConfirmationViewController, StakingConfirmationModuleOutput, Void> {
        let viewModel = StakingConfirmationViewModelImplementation(
            stakingModel: stakingModel,
            sendConfirmationController: sendConfirmationController
        )
        let viewController = StakingConfirmationViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
