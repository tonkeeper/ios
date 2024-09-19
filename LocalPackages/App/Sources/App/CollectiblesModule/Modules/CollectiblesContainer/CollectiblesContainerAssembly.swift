import Foundation
import TKCore
import KeeperCore

struct CollectiblesContainerAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<CollectiblesContainerViewController, CollectiblesContainerModuleOutput, Void> {
    let viewModel = CollectiblesContainerViewModelImplementation(walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore)
    let viewController = CollectiblesContainerViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
