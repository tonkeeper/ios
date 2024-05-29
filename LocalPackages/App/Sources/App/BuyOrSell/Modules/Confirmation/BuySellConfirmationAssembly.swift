import Foundation
import TKCore
import KeeperCore

struct BuySellConfirmationAssembly {
    static func module(
        itemModel: BuySellItemModel,
        type: BuySellConfirmationType,
        currency: Currency,
        confirmationInputController: ConfirmationInputController
    ) -> MVVMModule<BuySellConfirmationViewController, BuySellConfirmationModuleOutput, BuySellConfirmationModuleInput> {
        let viewModel = BuySellConfirmationViewModelImplementation(
            itemModel: itemModel,
            type: type,
            currency: currency,
            confirmationInputController: confirmationInputController
        )
        let viewController = BuySellConfirmationViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
