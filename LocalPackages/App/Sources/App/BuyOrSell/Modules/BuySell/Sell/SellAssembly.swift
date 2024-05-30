import Foundation
import TKCore
import KeeperCore

struct SellAssembly {
    static func module(sellInputController: SellInputController) -> MVVMModule<BuySellViewController, BuySellModuleOutput, BuySellModuleInput> {
        let viewModel = SellViewModelImplementation(sellInputController: sellInputController)
        let viewController = BuySellViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
