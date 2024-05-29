import Foundation
import TKCore
import KeeperCore

struct BuyAssembly {
    static func module(
        buyInputController: BuyInputController
    ) -> MVVMModule<BuySellViewController, BuySellModuleOutput, BuySellModuleInput> {
        let viewModel = BuyViewModelImplementation(buyInputController: buyInputController)
        let viewController = BuySellViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
