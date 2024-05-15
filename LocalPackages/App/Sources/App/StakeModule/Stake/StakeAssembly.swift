import Foundation
import TKCore
import KeeperCore

struct StakeAssembly {
  private init() {}
    
  static func module(coreAssembly: TKCore.CoreAssembly,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     walletsStore: WalletsStore
  ) -> MVVMModule<StakeViewController, StakeModulOutput, StakeModulInput> {
      
    let viewModel = StakeViewModelImplementation(
      sendController: keeperCoreMainAssembly.sendV3Controller(), 
      walletsStore: walletsStore,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    
    let viewController = StakeViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
