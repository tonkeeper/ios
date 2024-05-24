import Foundation
import TKCore
import KeeperCore

struct SwapItemsAssembly {
  private init() {}
  static func module(sellItem: SwapItem,
                     buyItem: SwapItem?,
                     slippage: Float,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<SwapItemsViewController, SwapItemsModuleOutput, SwapItemsModuleInput> {
    let viewModel = SwapItemsViewModelImplementation(
      sellItem: sellItem,
      buyItem: buyItem,
      slippage: slippage,
      swapItemsController: keeperCoreMainAssembly.swapItemsController(),
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletStore
    )
    let viewController = SwapItemsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}

