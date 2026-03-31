import Foundation
import KeeperCore
import TKCore

@MainActor
struct BrowserAssembly {
    private init() {}
    static func module(
        keeperCoreAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> MVVMModule<BrowserViewController, BrowserModuleOutput, BrowserModuleInput> {
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
            analyticsProvider: coreAssembly.analyticsProvider
        )
        let viewController = BrowserViewController(
            viewModel: viewModel,
            exploreViewController: exploreModule.view,
            connectedViewController: connectedModule.view
        )

        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
