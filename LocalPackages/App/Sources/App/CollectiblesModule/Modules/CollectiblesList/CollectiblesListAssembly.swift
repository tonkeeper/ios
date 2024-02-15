import Foundation
import TKCore
import KeeperCore

struct CollectiblesListAssembly {
  private init() {}
  static func module(
    collectiblesListController: CollectiblesListController
  ) -> MVVMModule<CollectiblesListViewController, CollectiblesListModuleOutput, Void> {
    let viewModel = CollectiblesListViewModelImplementation(collectiblesListController: collectiblesListController)
    let viewController = CollectiblesListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
