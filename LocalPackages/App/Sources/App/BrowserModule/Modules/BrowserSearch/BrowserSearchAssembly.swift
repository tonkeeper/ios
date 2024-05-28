import Foundation
import TKCore
import KeeperCore

struct BrowserSearchAssembly {
  private init() {}
  static func module(keeperCoreAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<BrowserSearchViewController, BrowserSearchModuleOutput, Void> {

    let viewModel = BrowserSearchViewModelImplementation(
      popularAppsService: keeperCoreAssembly.servicesAssembly.popularAppsService()
    )
    let viewController = BrowserSearchViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
