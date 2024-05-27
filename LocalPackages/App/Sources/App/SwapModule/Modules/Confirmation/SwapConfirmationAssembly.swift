import Foundation
import TKCore
import KeeperCore

struct SwapConfirmationAssembly {
  private init() {}
  static func module(swapItem: SwapItem,
                     coreAssembly: TKCore.CoreAssembly,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<SwapConfirmationViewController, SwapConfirmationModuleOutput, SwapConfirmationModuleInput> {
    let viewModel = SwapConfirmationViewModelImplementation(
      swapItem: swapItem,
      swapController: keeperCoreMainAssembly.swapController(),
      swapConfirmationController: keeperCoreMainAssembly.swapConfirmationController(item: swapItem)
    )
    let viewController = SwapConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
