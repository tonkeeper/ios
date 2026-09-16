import Foundation
import KeeperCore
import TKCore

struct BrowserCategoryMultichainAssembly {
    private init() {}

    static func module(
        category: PopularAppsCategory,
        walletStore: WalletsStore,
        supportedChains: [MultichainChain],
        initialChain: MultichainChain?
    ) -> MVVMModule<BrowserCategoryMultichainViewController, BrowserCategoryModuleOutput, Void> {
        let viewModel = BrowserCategoryMultichainViewModelImplementation(
            category: category,
            walletStore: walletStore,
            supportedChains: supportedChains,
            initialChain: initialChain
        )
        let viewController = BrowserCategoryMultichainViewController(
            viewModel: viewModel
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
