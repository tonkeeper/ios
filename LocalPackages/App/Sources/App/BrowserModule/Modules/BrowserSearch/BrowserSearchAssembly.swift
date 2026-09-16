import Foundation
import KeeperCore
import TKCore

struct BrowserSearchAssembly {
    private init() {}
    static func module(
        keeperCoreAssembly: KeeperCore.MainAssembly
    )
        -> MVVMModule<BrowserSearchViewController, BrowserSearchModuleOutput, Void>
    {
        let viewModel = BrowserSearchViewModelImplementation(
            popularAppsService: keeperCoreAssembly.servicesAssembly.popularAppsService(),
            appSettingsStore: keeperCoreAssembly.storesAssembly.appSettingsStore,
            searchEngineService: keeperCoreAssembly.servicesAssembly.searchEngineService(),
            isMultichainEnabled: keeperCoreAssembly.configurationAssembly.configuration.featureEnabled(.multichainEnabled)
        )
        let viewController = BrowserSearchViewController(viewModel: viewModel)

        return .init(view: viewController, output: viewModel, input: ())
    }
}
