import Foundation
import KeeperCore
import TKCore

struct BrowserConnectedAssembly {
    private init() {}
    static func module(
        keeperCoreAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    )
        -> MVVMModule<BrowserConnectedViewController, BrowserConnectedModuleOutput, Void>
    {
        let tonConnectStore = keeperCoreAssembly.tonConnectAssembly.tonConnectAppsStore
        let connectedAppsStore = keeperCoreAssembly.storesAssembly.connectedAppsStore(
            tonConnectAppsStore: tonConnectStore
        )
        let viewModel = BrowserConnectedViewModelImplementation(
            walletsStore: keeperCoreAssembly.storesAssembly.walletsStore,
            connectedAppsStore: connectedAppsStore,
            notificationsService: keeperCoreAssembly.servicesAssembly.notificationsService(
                walletNotificationsStore: keeperCoreAssembly.storesAssembly.walletNotificationStore,
                tonConnectAppsStore: keeperCoreAssembly.tonConnectAssembly.tonConnectAppsStore
            ),
            pushTokenProvider: PushNotificationTokenProvider(),
            analyticsProvider: coreAssembly.analyticsProvider
        )
        let viewController = BrowserConnectedViewController(
            viewModel: viewModel
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
