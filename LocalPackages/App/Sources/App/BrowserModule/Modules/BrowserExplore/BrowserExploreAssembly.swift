import Foundation
import TKCore
import KeeperCore

struct BrowserExploreAssembly {
  private init() {}
  static func module(keeperCoreAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<BrowserExploreViewController, BrowserExploreModuleOutput, Void> {

    let viewModel = BrowserExploreViewModelImplementation(
      browserExploreController: keeperCoreAssembly.browserExploreController(),
      regionStore: keeperCoreAssembly.storesAssembly.regionStore,
      configurationStore: keeperCoreAssembly.configurationAssembly.configurationStore
    )
    let viewController = BrowserExploreViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
