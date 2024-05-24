import Foundation
import TKCore
import KeeperCore

struct SwapConfirmationAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     sellItem: SwapItem,
                     buyItem: SwapItem,
                     estimate: SwapEstimate,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<SwapConfirmationViewController,
                                                                                    SwapConfirmationModuleOutput,
                                                                                    SwapConfirmationModuleInput> {
    let viewModel = SwapConfirmationViewModelImplementation(
      sellItem: sellItem,
      buyItem: buyItem,
      estimate: estimate,
      swapConfirmationController: keeperCoreMainAssembly.swapConfirmationController(wallet: wallet),
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletStore
    )
    let viewController = SwapConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}

