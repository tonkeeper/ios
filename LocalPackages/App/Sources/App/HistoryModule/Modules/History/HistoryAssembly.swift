import Foundation
import TKCore

struct HistoryAssembly {
    private init() {}
    @MainActor static func module(
        historyListViewController: HistoryListViewController,
        historyListModuleInput: HistoryListModuleInput,
        closeAction: (() -> Void)?
    ) -> MVVMModule<HistoryViewController, HistoryModuleOutput, HistoryModuleInput> {
        let viewModel = HistoryV2ViewModelImplementation(
            historyListModuleInput: historyListModuleInput,
            closeAction: closeAction
        )
        let viewController = HistoryViewController(
            viewModel: viewModel,
            historyListViewController: historyListViewController
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
