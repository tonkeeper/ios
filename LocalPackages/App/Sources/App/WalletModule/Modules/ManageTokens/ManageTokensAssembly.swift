import Foundation
import KeeperCore
import TKCore

struct ManageTokensAssembly {
    private init() {}
    static func module(
        model: ManageTokensModel,
        mapper: ManageTokensListMapper,
        updateQueue: DispatchQueue,
        configuration: Configuration
    ) -> MVVMModule<ManageTokensViewController, Void, Void> {
        let viewModel = ManageTokensViewModelImplementation(
            model: model,
            mapper: mapper,
            updateQueue: updateQueue,
            configuration: configuration
        )

        let viewController = ManageTokensViewController(viewModel: viewModel)
        return .init(view: viewController, output: (), input: ())
    }
}
