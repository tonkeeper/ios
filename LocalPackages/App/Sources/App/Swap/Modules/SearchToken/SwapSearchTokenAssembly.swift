import Foundation
import TKCore
import KeeperCore

struct SwapSearchTokenAssembly {
  private init() {}
  static func module(swapSearchTokenController: SwapSearchTokenController) -> MVVMModule<SwapSearchTokenViewController, SwapSearchTokenModuleOutput, SwapSearchTokenModuleInput> {
    let viewModel = SwapSearchTokenViewModelImplementation(swapSearchTokenController: swapSearchTokenController)
    let viewController = SwapSearchTokenViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
