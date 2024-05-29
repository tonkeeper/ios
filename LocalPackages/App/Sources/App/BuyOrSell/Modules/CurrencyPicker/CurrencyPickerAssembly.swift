import Foundation
import TKCore
import KeeperCore

struct CurrencyPickerAssembly {
    static func module(selectedCurrency: Currency?, settingsController: SettingsController) -> MVVMModule<CurrencyPickerViewController, CurrencyPickerModuleOutput, CurrencyPickerModuleInput> {
        let viewModel = CurrencyPickerViewModelImplementation(
            selectedCurrency: selectedCurrency,
            settingsController: settingsController
        )
        let viewController = CurrencyPickerViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
