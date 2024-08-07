import Foundation
import TKCore
import KeeperCore

struct HistoryAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<HistoryViewController, HistoryModuleOutput, HistoryModuleInput> {
    let viewModel = HistoryV2ViewModelImplementation(
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
      backgroundUpdateStore: keeperCoreMainAssembly.mainStoresAssembly.backgroundUpdateStore
    )
    let viewController = HistoryViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
