import Foundation
import KeeperCore
import TKCore

struct HistoryAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        historyListViewController: HistoryListViewController,
        historyListModuleInput: HistoryListModuleInput,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    )
        -> MVVMModule<HistoryViewController, HistoryModuleOutput, HistoryModuleInput>
    {
        let viewModel = HistoryV2ViewModelImplementation(
            wallet: wallet,
            backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate,
            historyListModuleInput: historyListModuleInput
        )
        let viewController = HistoryViewController(
            viewModel: viewModel,
            historyListViewController: historyListViewController
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
