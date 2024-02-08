import Foundation
import TKCore
import KeeperCore

struct HistoryAssembly {
  private init() {}
  static func module(historyController: HistoryController,
                     listModuleProvider: @escaping (Wallet) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput>,
                     emptyModuleProvider: @escaping (Wallet) -> MVVMModule<HistoryEmptyViewController, HistoryEmptyViewModel, Void>)
  -> MVVMModule<HistoryViewController, HistoryModuleOutput, Void> {

    let viewModel = HistoryViewModelImplementation(
      historyController: historyController,
      listModuleProvider: listModuleProvider,
      emptyModuleProvider: emptyModuleProvider
    )
    let viewController = HistoryViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
