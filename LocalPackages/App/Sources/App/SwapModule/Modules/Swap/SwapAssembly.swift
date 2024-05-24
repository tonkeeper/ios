import UIKit
import TKCore
import KeeperCore

struct SwapAssembly {
  private init() {}
  static func module(swapController: SwapController,
                     swapOperationItem: SwapOperationItem,
                     swapSettingsModel: SwapSettingsModel) -> MVVMModule<SwapViewController, SwapModuleOutput, SwapModuleInput> {
    let viewModel = SwapViewModelImplementation(
      swapController: swapController,
      swapOperationItem: swapOperationItem,
      swapSettingsModel: swapSettingsModel
    )
    
    let viewController = SwapViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
