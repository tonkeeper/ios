import Foundation
import TKCore
import KeeperCore

struct HistoryContainerAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<HistoryContainerViewController, HistoryContainerModuleOutput, Void> {
    let viewModel = HistoryContainerViewModelImplementation(walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore)
    let viewController = HistoryContainerViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
