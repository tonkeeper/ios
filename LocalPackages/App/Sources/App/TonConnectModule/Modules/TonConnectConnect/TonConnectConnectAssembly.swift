import KeeperCore
import TKCore
import UIKit

struct TonConnectConnectAssembly {
    private init() {}

    static func module(
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        walletsStore: WalletsStore,
        walletNotificationStore: WalletNotificationStore,
        notificationsService: NotificationsService,
        pushTokenProvider: PushNotificationTokenProvider,
        showWalletPicker: Bool,
        isSafeMode: Bool
    ) -> MVVMModule<
        TonConnectConnectViewController,
        TonConnectConnectViewModuleOutput,
        TonConnectConnectModuleInput
    > {
        let viewModel = TonConnectConnectViewModelImplementation(
            parameters: parameters,
            manifest: manifest,
            walletsStore: walletsStore,
            walletNotificationStore: walletNotificationStore,
            notificationsService: notificationsService,
            pushTokenProvider: pushTokenProvider,
            showWalletPicker: showWalletPicker,
            isSafeMode: isSafeMode
        )
        let viewController = TonConnectConnectViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
