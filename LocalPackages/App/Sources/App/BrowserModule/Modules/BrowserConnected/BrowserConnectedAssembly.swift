import Foundation
import KeeperCore
import TKCore
import TKFeatureFlags

@MainActor
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
            tonConnectConnectionMetadataStore: keeperCoreAssembly.tonConnectAssembly.tonConnectConnectionMetadataStore,
            walletConnectSessionsStoreProvider: {
                guard keeperCoreAssembly.configurationAssembly.configuration.featureEnabled(.multichainEnabled) else {
                    return nil
                }

                let walletConnectService = await keeperCoreAssembly.walletConnectAssembly.walletConnectService
                return keeperCoreAssembly.storesAssembly.walletConnectSessionsStore(
                    walletConnectService: walletConnectService
                )
            },
            notificationsService: keeperCoreAssembly.servicesAssembly.notificationsService(
                walletNotificationsStore: keeperCoreAssembly.storesAssembly.walletNotificationStore,
                tonConnectAppsStore: keeperCoreAssembly.tonConnectAssembly.tonConnectAppsStore
            ),
            pushTokenProvider: PushNotificationTokenProvider()
        )
        let viewController = BrowserConnectedViewController(
            viewModel: viewModel
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
