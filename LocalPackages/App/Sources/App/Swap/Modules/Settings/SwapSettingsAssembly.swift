import Foundation
import TKCore

struct SwapSettingsAssembly {
    static func module(currentTolerance: Int) -> MVVMModule<SwapSettingsViewController, SwapSettingsModuleOutput, SwapSettingsModuleInput> {
        let viewModel = SwapSettingsViewModelImplementation(currentTolerance: currentTolerance)
        let viewController = SwapSettingsViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
