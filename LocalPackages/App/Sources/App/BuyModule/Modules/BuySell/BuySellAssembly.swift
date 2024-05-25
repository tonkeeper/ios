import UIKit
import TKCore
import KeeperCore

struct BuySellAssembly {
  private init() {}
  static func module(buySellController: BuySellController,
                     appSettings: AppSettings,
                     buySellModel: BuySellModel) -> MVVMModule<BuySellViewController, BuySellModuleOutput, Void> {
    let viewModel = BuySellViewModelImplementation(
      buySellController: buySellController,
      appSettings: appSettings,
      buySellModel: buySellModel
    )
    
    let viewController = BuySellViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}
