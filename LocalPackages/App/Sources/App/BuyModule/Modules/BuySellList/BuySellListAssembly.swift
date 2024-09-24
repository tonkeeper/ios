import UIKit
import TKCore
import KeeperCore

struct BuySellListAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BuySellListViewController, BuySellListModuleOutput, BuySellListModuleInput> {
    let viewModel = BuySellListViewModelImplementation(
      wallet: wallet,
      fiatMethodsStore: keeperCoreMainAssembly.storesAssembly.fiatMethodsStore,
      walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      configurationStore: keeperCoreMainAssembly.configurationAssembly.configurationStore,
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


