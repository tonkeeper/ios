import Foundation
import TKCore
import KeeperCore

struct BrowserAssembly {
  private init() {}
  static func module(
    keeperCoreAssembly: KeeperCore.MainAssembly,
    coreAssembly: TKCore.CoreAssembly
  ) -> MVVMModule<BrowserViewController, BrowserModuleOutput, BrowserModuleInput> {

    let exploreModule = BrowserExploreAssembly.module(keeperCoreAssembly: keeperCoreAssembly)
    let connectedModule = BrowserConnectedAssembly.module(keeperCoreAssembly: keeperCoreAssembly)

    let viewModel = BrowserViewModelImplementation(
      exploreModuleOutput: exploreModule.output,
      connectedModuleOutput: connectedModule.output,
      appSettings: coreAssembly.appSettings
    )
    let viewController = BrowserViewController(
      viewModel: viewModel,
      exploreViewController: exploreModule.view,
      connectedViewController: connectedModule.view
    )

    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
