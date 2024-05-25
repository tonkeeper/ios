import Foundation
import TKCore
import KeeperCore

struct ChooseTokenAssembly {
  private init() {}
  static func module(excludeToken: Token?,
                     coreAssembly: TKCore.CoreAssembly,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<ChooseTokenViewController, ChooseTokenModuleOutput, Void> {
    let viewModel = ChooseTokenViewModelImplementation(
      excludeToken: excludeToken,
      swapAvailableTokenController: keeperCoreMainAssembly.swapAvailableTokenController()
    )
    let viewController = ChooseTokenViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}

