import Foundation
import TKCore
import KeeperCore

struct CollectiblesAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     collectiblesListViewController: CollectiblesListViewController,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<CollectiblesViewController, CollectiblesModuleOutput, CollectiblesModuleInput> {
    let viewModel = CollectiblesViewModelImplementation(
      wallet: wallet,
      walletNFTManagedStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagedStore(wallet: wallet),
      backgroundUpdateStore: keeperCoreMainAssembly.storesAssembly.backgroundUpdateStore,
      walletStateLoader: keeperCoreMainAssembly.loadersAssembly.walletStateLoader
    )
    let viewController = CollectiblesViewController(
      viewModel: viewModel,
      collectiblesListViewController: collectiblesListViewController
    )
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
