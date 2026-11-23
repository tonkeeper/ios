import Foundation
import KeeperCore
import TKCore
import UIKit

@MainActor
struct ChooseWalletKindAssembly {
    private init() {}

    static func module(
        options: [ChooseWalletKindOption],
        amountFormatter: AmountFormatter,
        currency: Currency
    ) -> MVVMModule<UIViewController, ChooseWalletKindModuleOutput, ChooseWalletKindModuleInput> {
        let viewModel = ChooseWalletKindViewModel(
            options: options,
            amountFormatter: amountFormatter,
            currency: currency
        )
        let viewController = ChooseWalletKindHostingViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
