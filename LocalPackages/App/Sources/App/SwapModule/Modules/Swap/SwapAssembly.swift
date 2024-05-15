import UIKit
import TKCore
import KeeperCore

struct SwapAssembly {
  private init() {}
  static func module(swapController: SwapController, swapItem: SwapItem) -> MVVMModule<SwapViewController, SwapModuleOutput, SwapModuleInput> {
    let viewModel = SwapViewModelImplementation(
      swapController: swapController,
      swapItem: swapItem
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
