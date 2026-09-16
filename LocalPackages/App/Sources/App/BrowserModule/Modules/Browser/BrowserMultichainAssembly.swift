import Foundation
import KeeperCore
import TKCore

@MainActor
struct BrowserMultichainAssembly {
    private init() {}

    static func module(
        keeperCoreAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        analyticsController: DappBrowserAnalyticsController
    ) -> MVVMModule<BrowserMultichainViewController, BrowserModuleOutput, BrowserModuleInput> {
        let exploreViewModel = BrowserExploreMultichainViewModelImplementation(
            browserExploreController: keeperCoreAssembly.browserExploreController(),
            walletStore: keeperCoreAssembly.storesAssembly.walletsStore,
            regionStore: keeperCoreAssembly.storesAssembly.regionStore,
            configuration: keeperCoreAssembly.configurationAssembly.configuration,
            deeplinkParser: keeperCoreAssembly.deeplinkParser,
            supportedChains: keeperCoreAssembly.multichainAssembly.supportedChains
        )

        let tonConnectStore = keeperCoreAssembly.tonConnectAssembly.tonConnectAppsStore
        let connectedAppsStore = keeperCoreAssembly.storesAssembly.connectedAppsStore(
            tonConnectAppsStore: tonConnectStore
        )
        let connectedViewModel = BrowserConnectedMultichainViewModelImplementation(
            walletsStore: keeperCoreAssembly.storesAssembly.walletsStore,
            connectedAppsStore: connectedAppsStore,
            tonConnectConnectionMetadataStore: keeperCoreAssembly.tonConnectAssembly.tonConnectConnectionMetadataStore,
            walletConnectSessionsStoreProvider: {
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

        let viewModel = BrowserMultichainViewModelImplementation(
            exploreModuleInput: exploreViewModel,
            exploreModuleOutput: exploreViewModel,
            connectedModuleOutput: connectedViewModel,
            analyticsController: analyticsController
        )
        let viewController = BrowserMultichainViewController(
            viewModel: viewModel,
            exploreViewModel: exploreViewModel,
            connectedViewModel: connectedViewModel
        )

        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
