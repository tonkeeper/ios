import Foundation

import Foundation
import TKCore
import KeeperCore

struct SwapAssembly {
  private init() {}
  static func module(coreAssembly: TKCore.CoreAssembly,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<SwapViewController, SwapModuleOutput, SwapModuleInput> {
    let viewModel = SwapViewModelImplementation()
    let viewController = SwapViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
