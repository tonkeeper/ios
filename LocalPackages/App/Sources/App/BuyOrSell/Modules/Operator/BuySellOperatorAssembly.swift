import Foundation
import TKCore
import KeeperCore

struct BuySellOperatorAssembly {
    static func module(
        operatorsController: OperatorsController,
        settingsController: SettingsController
    ) -> MVVMModule<BuySellOperatorViewController, BuySellOperatorModuleOutput, BuySellOperatorModuleInput> {
        let viewModel = BuySellOperatorViewModelImplementation(
            operatorsController: operatorsController,
            settingsController: settingsController
        )
        let viewController = BuySellOperatorViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
