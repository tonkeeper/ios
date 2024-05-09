import UIKit
import TKCore
import KeeperCore

struct BuySellAssembly {
  private init() {}
  static func module(buySellController: BuySellController,
                     appSettings: AppSettings,
                     buySellItem: BuySellItem) -> MVVMModule<BuySellViewController, BuySellModuleOutput, BuySellModuleInput> {
    let viewModel = BuySellViewModelImplementation(
      buySellController: buySellController,
      appSettings: appSettings,
      buySellItem: buySellItem
    )
    
    let viewController = BuySellViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
