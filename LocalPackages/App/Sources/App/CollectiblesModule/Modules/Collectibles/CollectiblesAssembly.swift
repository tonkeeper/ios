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
      backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate,
      walletBalanceLoader: keeperCoreMainAssembly.loadersAssembly.walletBalanceLoaders(wallet: wallet)
    )
    let viewController = CollectiblesViewController(
      viewModel: viewModel,
      collectiblesListViewController: collectiblesListViewController
    )
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
