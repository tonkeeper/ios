import UIKit
import TKCore
import KeeperCore

struct SwapConfirmationAssembly {
  private init() {}
  static func module(swapConfirmationController: SwapConfirmationController,
                     swapConfirmationItem: SwapConfirmationItem) -> MVVMModule<SwapConfirmationViewController, SwapConfirmationModuleOutput, SwapConfirmationModuleInput> {
    let viewModel = SwapConfirmationViewModelImplementation(
      swapConfirmationController: swapConfirmationController,
      swapConfirmationItem: swapConfirmationItem
    )
    
    let viewController = SwapConfirmationViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
