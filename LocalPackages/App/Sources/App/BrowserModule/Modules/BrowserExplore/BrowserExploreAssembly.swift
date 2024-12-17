import Foundation
import TKCore
import KeeperCore

struct BrowserExploreAssembly {
  private init() {}
  static func module(keeperCoreAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly)
  -> MVVMModule<BrowserExploreViewController, BrowserExploreModuleOutput, Void> {

    let viewModel = BrowserExploreViewModelImplementation(
      browserExploreController: keeperCoreAssembly.browserExploreController(),
      walletStore: keeperCoreAssembly.storesAssembly.walletsStore,
      regionStore: keeperCoreAssembly.storesAssembly.regionStore,
      analyticsProvider: coreAssembly.analyticsProvider
    )
    let viewController = BrowserExploreViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
