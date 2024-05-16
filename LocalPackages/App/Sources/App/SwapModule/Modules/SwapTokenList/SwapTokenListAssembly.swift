import UIKit
import TKCore
import KeeperCore

struct SwapTokenListAssembly {
  private init() {}
  static func module(swapTokenListController: SwapTokenListController) -> MVVMModule<SwapTokenListViewController, SwapTokenListModuleOutput, SwapTokenListModuleInput> {
    let viewModel = SwapTokenListViewModelImplementation(
      swapTokenListController: swapTokenListController
    )
    
    let viewController = SwapTokenListViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}
