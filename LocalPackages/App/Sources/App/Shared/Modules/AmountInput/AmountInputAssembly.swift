import KeeperCore
import TKCore
import UIKit

struct AmountInputAssembly {
    private init() {}
    static func module(
        sourceUnit: AmountInputUnit,
        destinationUnit: AmountInputUnit,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        textFieldAccessibilityIdentifier: String? = nil
    ) -> MVVMModule<AmountInputViewController, AmountInputModuleOutput, AmountInputModuleInput> {
        let viewModel = swiftUIModule(
            sourceUnit: sourceUnit,
            destinationUnit: destinationUnit,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        let viewController = AmountInputViewController(
            viewModel: viewModel,
            textFieldAccessibilityIdentifier: textFieldAccessibilityIdentifier
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }

    static func swiftUIModule(
        sourceUnit: AmountInputUnit,
        destinationUnit: AmountInputUnit,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> AmountInputSwiftUIViewModel {
        AmountInputSwiftUIViewModel(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            sourceUnit: sourceUnit,
            destinationUnit: destinationUnit
        )
    }
}
