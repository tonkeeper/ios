import Foundation
import TKCore
import KeeperCore

struct HistoryAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     historyListViewController: HistoryListViewController,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<HistoryViewController, HistoryModuleOutput, Void> {
    let viewModel = HistoryV2ViewModelImplementation(
      wallet: wallet,
      backgroundUpdateStore: keeperCoreMainAssembly.storesAssembly.backgroundUpdateStore
    )
    let viewController = HistoryViewController(
      viewModel: viewModel,
      historyListViewController: historyListViewController
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
