import Foundation
import TKCore
import KeeperCore

struct SwapConfirmationAssembly {
  private init() {}
  static func module(swapPair: SwapPair,
                     coreAssembly: TKCore.CoreAssembly,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<SwapConfirmationViewController, SwapConfirmationModuleOutput, SwapConfirmationModuleInput> {
    let viewModel = SwapConfirmationViewModelImplementation(
      swapPair: swapPair,
      swapController: keeperCoreMainAssembly.swapController(),
      swapConfirmationController: keeperCoreMainAssembly.swapConfirmationController()
    )
    let viewController = SwapConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
