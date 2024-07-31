import UIKit
import TKCore
import KeeperCore

struct BuySellListAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BuySellListViewController, BuySellListModuleOutput, BuySellListModuleInput> {
    let viewModel = BuySellListViewModelImplementation(
      fiatMethodsStore: keeperCoreMainAssembly.storesAssembly.fiatMethodsStore,
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      configurationStore: keeperCoreMainAssembly.configurationAssembly.remoteConfigurationStore,
      appSettings: coreAssembly.appSettings
    )
    
    let viewController = BuySellListViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}


