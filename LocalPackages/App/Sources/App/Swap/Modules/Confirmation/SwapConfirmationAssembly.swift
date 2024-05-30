import Foundation
import TKCore
import KeeperCore

struct SwapConfirmationAssembly {
    static func module(
        swapInfoController: SwapInfoController,
        sendConfirmationController: SendConfirmationController
    ) -> MVVMModule<SwapConfirmationViewController, SwapConfirmationModuleOutput, SwapConfirmationModuleInput> {
        let viewModel = SwapConfirmationViewModelImplementation(
            swapInfoController: swapInfoController,
            sendConfirmationController: sendConfirmationController
        )
        let viewController = SwapConfirmationViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
