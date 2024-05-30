import Foundation
import TKCore
import KeeperCore

struct SwapAssembly {
  private init() {}
  static func module(token: Token,
                     coreAssembly: TKCore.CoreAssembly,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<SwapViewController, SwapModuleOutput, SwapModuleInput> {
    let viewModel = SwapViewModelImplementation(
      swapItem: SwapPair.Item(token: token, amount: 0),
      swapController: keeperCoreMainAssembly.swapController()
    )
    let viewController = SwapViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
