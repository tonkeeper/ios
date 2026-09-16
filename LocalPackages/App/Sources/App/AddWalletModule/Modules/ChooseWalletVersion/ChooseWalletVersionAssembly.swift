import Foundation
import KeeperCore
import TKCore
import UIKit

@MainActor
struct ChooseWalletVersionAssembly {
    private init() {}

    static func module(
        wallets: [ActiveWalletModel],
        amountFormatter: AmountFormatter,
        network: Network,
        tonRate: Rates.Rate?,
        currency: Currency
    ) -> MVVMModule<UIViewController, ChooseWalletVersionModuleOutput, ChooseWalletVersionModuleInput> {
        let viewModel = ChooseWalletVersionViewModel(
            wallets: wallets,
            amountFormatter: amountFormatter,
            network: network,
            tonRate: tonRate,
            currency: currency
        )
        let viewController = ChooseWalletVersionHostingViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
