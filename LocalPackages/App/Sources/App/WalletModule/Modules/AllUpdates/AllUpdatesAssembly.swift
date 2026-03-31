import Foundation
import KeeperCore
import TKCore

struct AllUpdatesAssembly {
    private init() {}

    static func module(
        storiesStore: StoriesStore
    ) -> MVVMModule<AllUpdatesViewController, AllUpdatesModuleOutput, Void> {
        let viewModel = AllUpdatesViewModelImplementation(
            storiesStore: storiesStore
        )
        let viewController = AllUpdatesViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}
