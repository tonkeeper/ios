import Foundation
import KeeperCore
import TKCore

@MainActor
struct BrowserExploreAssembly {
    private init() {}
    static func module(
        keeperCoreAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    )
        -> MVVMModule<BrowserExploreViewController, BrowserExploreModuleOutput, BrowserExploreModuleInput>
    {
        let viewModel = BrowserExploreViewModelImplementation(
            browserExploreController: keeperCoreAssembly.browserExploreController(),
            walletStore: keeperCoreAssembly.storesAssembly.walletsStore,
            regionStore: keeperCoreAssembly.storesAssembly.regionStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            configuration: keeperCoreAssembly.configurationAssembly.configuration
        )
        let viewController = BrowserExploreViewController(
            viewModel: viewModel
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
