import Foundation
import KeeperCore
import TKCore

struct WalletContainerAssembly {
    private init() {}
    static func module(
        walletBalanceModule: WalletBalanceModule,
        walletsStore: WalletsStore
    ) -> MVVMModule<WalletContainerViewController, WalletContainerModuleOutput, Void> {
        module(
            walletBalanceViewController: walletBalanceModule.view,
            walletsStore: walletsStore
        )
    }

    static func module(
        walletBalanceViewController: WalletContainerBalanceViewController,
        walletsStore: WalletsStore
    ) -> MVVMModule<WalletContainerViewController, WalletContainerModuleOutput, Void> {
        let viewModel = WalletContainerViewModelImplementation(
            walletsStore: walletsStore
        )
        let viewController = WalletContainerViewController(
            viewModel: viewModel,
            walletBalanceViewController: walletBalanceViewController
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
