import Foundation
import KeeperCore
import TKCore
import UIKit

@MainActor
struct ChooseWalletKindAssembly {
    private init() {}

    static func module(
        tonPreview: ImportWalletKindPreview,
        multichainPreview: ImportWalletKindPreview,
        amountFormatter: AmountFormatter,
        currency: Currency
    ) -> MVVMModule<UIViewController, ChooseWalletKindModuleOutput, ChooseWalletKindModuleInput> {
        let viewModel = ChooseWalletKindViewModel(
            tonPreview: tonPreview,
            multichainPreview: multichainPreview,
            amountFormatter: amountFormatter,
            currency: currency
        )
        let viewController = ChooseWalletKindHostingViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
