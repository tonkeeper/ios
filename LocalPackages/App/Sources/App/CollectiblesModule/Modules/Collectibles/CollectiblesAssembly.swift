import Foundation
import TKCore
import KeeperCore

struct CollectiblesAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<CollectiblesViewController, CollectiblesModuleOutput, CollectiblesModuleInput> {
    let viewModel = CollectiblesViewModelImplementation(
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
      backgroundUpdateStore: keeperCoreMainAssembly.mainStoresAssembly.backgroundUpdateStore
    )
    let viewController = CollectiblesViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
