import Foundation
import TKCore
import KeeperCore

struct CollectiblesListAssembly {
  private init() {}
  static func module(
    wallet: Wallet,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<CollectiblesListViewController, CollectiblesListModuleOutput, Void> {
    let viewModel = CollectiblesListViewModelImplementation(
      wallet: wallet,
      walletNFTsManagedStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagedStore(wallet: wallet),
      walletNftManagementStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet),
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore
    )
    let viewController = CollectiblesListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
