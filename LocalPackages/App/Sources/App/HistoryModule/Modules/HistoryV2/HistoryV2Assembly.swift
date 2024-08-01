import Foundation
import TKCore
import KeeperCore

struct HistoryV2Assembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<HistoryV2ViewController, HistoryV2ModuleOutput, HistoryV2ModuleInput> {
    let viewModel = HistoryV2ViewModelImplementation(
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
      backgroundUpdateStore: keeperCoreMainAssembly.mainStoresAssembly.backgroundUpdateStore
    )
    let viewController = HistoryV2ViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
