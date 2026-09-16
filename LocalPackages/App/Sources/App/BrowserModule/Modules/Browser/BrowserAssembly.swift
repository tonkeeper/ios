import Foundation
import KeeperCore
import TKCore
import TKFeatureFlags
import UIKit

@MainActor
struct BrowserAssembly {
    private init() {}
    static func module(
        keeperCoreAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        analyticsController: DappBrowserAnalyticsController
    ) -> MVVMModule<UIViewController, BrowserModuleOutput, BrowserModuleInput> {
        if keeperCoreAssembly.configurationAssembly.configuration.featureEnabled(.multichainEnabled) {
            let module = BrowserMultichainAssembly.module(
                keeperCoreAssembly: keeperCoreAssembly,
                coreAssembly: coreAssembly,
                analyticsController: analyticsController
            )
            return .init(view: module.view, output: module.output, input: module.input)
        }

        let exploreModule = BrowserExploreAssembly.module(
            keeperCoreAssembly: keeperCoreAssembly,
            coreAssembly: coreAssembly
        )
        let connectedModule = BrowserConnectedAssembly.module(
            keeperCoreAssembly: keeperCoreAssembly,
            coreAssembly: coreAssembly
        )

        let viewModel = BrowserViewModelImplementation(
            exploreModuleInput: exploreModule.input,
            exploreModuleOutput: exploreModule.output,
            connectedModuleOutput: connectedModule.output,
            analyticsController: analyticsController
        )
        let viewController = BrowserViewController(
            viewModel: viewModel,
            exploreViewController: exploreModule.view,
            connectedViewController: connectedModule.view
        )

        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
