import Foundation
import TKCore
import KeeperCore

struct ManageTokensAssembly {
  private init() {}
  static func module(model: ManageTokensModel,
                     mapper: ManageTokensListMapper) -> MVVMModule<ManageTokensViewController, ManageTokensModuleOutput, Void> {
    let viewModel = ManageTokensViewModelImplementation(
      model: model,
      mapper: mapper
    )
    
    let viewController = ManageTokensViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
