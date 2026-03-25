import Foundation
import KeeperCore
import TKCore

struct BrowserCategoryAssembly {
    private init() {}
    static func module(category: PopularAppsCategory)
        -> MVVMModule<BrowserCategoryViewController, BrowserCategoryModuleOutput, Void>
    {
        let viewModel = BrowserCategoryViewModelImplementation(
            category: category
        )
        let viewController = BrowserCategoryViewController(
            viewModel: viewModel
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
