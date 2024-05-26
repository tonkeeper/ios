import Foundation
import TKCore
import KeeperCore

struct BrowserConnectedAssembly {
  private init() {}
  static func module(keeperCoreAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<BrowserConnectedViewController, BrowserConnectedModuleOutput, Void> {

    let viewModel = BrowserConnectedViewModelImplementation(
      browserConnectedController: keeperCoreAssembly.browserConnectedController()
    )
    let viewController = BrowserConnectedViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
