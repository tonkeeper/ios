import Foundation
import KeeperCore
import TKCore
import UIKit

struct ChooseWalletToAddAssembly {
    private init() {}
    static func module(
        activeWalletModels: [ActiveWalletModel],
        configuration: ChooseWalletToAddConfiguration,
        amountFormatter: AmountFormatter,
        network: Network
    ) -> MVVMModule<UIViewController, ChooseWalletToAddModuleOutput, Void> {
        let viewModel = ChooseWalletToAddViewModelImplementation(
            activeWalletModels: activeWalletModels,
            amountFormatter: amountFormatter,
            configuration: configuration,
            network: network
        )
        let viewController = ChooseWalletToAddViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
