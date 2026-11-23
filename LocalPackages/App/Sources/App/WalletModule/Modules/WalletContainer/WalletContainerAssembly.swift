import Foundation
import KeeperCore
import TKCore

struct WalletContainerAssembly {
    private init() {}

    /// The liquid glass navigation bar is the system one of iOS 26; false keeps the custom top bar.
    static func usesSystemNavigationBar(configuration: Configuration) -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        return configuration.featureEnabled(.liquidGlassEnabled)
    }

    static func module(
        walletBalanceModule: WalletBalanceModule,
        walletsStore: WalletsStore,
        usesSystemNavigationBar: Bool = false
    ) -> MVVMModule<WalletContainerViewController, WalletContainerModuleOutput, Void> {
        module(
            walletBalanceViewController: walletBalanceModule.view,
            walletsStore: walletsStore,
            usesSystemNavigationBar: usesSystemNavigationBar
        )
    }

    static func module(
        walletBalanceViewController: WalletContainerBalanceViewController,
        walletsStore: WalletsStore,
        usesSystemNavigationBar: Bool = false
    ) -> MVVMModule<WalletContainerViewController, WalletContainerModuleOutput, Void> {
        let viewModel = WalletContainerViewModelImplementation(
            walletsStore: walletsStore
        )
        let viewController = WalletContainerViewController(
            viewModel: viewModel,
            walletBalanceViewController: walletBalanceViewController,
            usesSystemNavigationBar: usesSystemNavigationBar
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
