import Foundation
import TKCore
import KeeperCore

struct HistoryListAssembly {
  private init() {}
  static func module(historyListController: HistoryListController,
                     historyEventMapper: HistoryEventMapper) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput> {
    let viewModel = HistoryListViewModelImplementation(
      historyListController: historyListController,
      historyEventMapper: historyEventMapper
    )
    let viewController = HistoryListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
