import UIKit
import TKCore
import KeeperCore

struct TonConnectConnectAssembly {
  private init() {}
  static func module(tonConnectConnectController: TonConnectConnectController) -> MVVMModule<TonConnectConnectViewController, TonConnectConnectViewModuleOutput, TonConnectConnectModuleInput> {
    let viewModel = TonConnectConnectViewModelImplementation(
      tonConnectConnectController: tonConnectConnectController
    )
    let viewController = TonConnectConnectViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
