import UIKit
import TKCore
import KeeperCore

struct SwapAssembly {
  private init() {}
  static func module(swapController: SwapController,
                     swapOperationItem: SwapOperationItem) -> MVVMModule<SwapViewController, SwapModuleOutput, SwapModuleInput> {
    let viewModel = SwapViewModelImplementation(
      swapController: swapController,
      swapOperationItem: swapOperationItem
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
