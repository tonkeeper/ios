import Foundation
import KeeperCore
import TKCore

struct WalletContainerAssembly {
    private init() {}
    static func module(
        walletBalanceModule: WalletBalanceModule,
        walletsStore: WalletsStore,
        configuration: Configuration
    ) -> MVVMModule<WalletContainerViewController, WalletContainerModuleOutput, Void> {
        let viewModel = WalletContainerViewModelImplementation(
            walletsStore: walletsStore,
            configuration: configuration
        )
        let viewController = WalletContainerViewController(
            viewModel: viewModel,
            walletBalanceViewController: walletBalanceModule.view
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
