import Foundation
import TKCore
import KeeperCore

struct SwapInfoAssembly {
    static func module(
        swapInfoController: SwapInfoController
    ) -> MVVMModule<SwapInfoViewController, SwapInfoModuleOutput, SwapInfoModuleInput> {
        let viewModel = SwapInfoViewModelImplementation(
            swapInfoController: swapInfoController
        )
        let viewController = SwapInfoViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
