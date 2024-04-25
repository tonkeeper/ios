import Foundation
import TKCore
import KeeperCore

struct CollectiblesAssembly {
  private init() {}
  static func module(
    collectiblesController: CollectiblesController,
    listModuleProvider: @escaping (Wallet) -> MVVMModule<CollectiblesListViewController, CollectiblesListModuleOutput, Void>,
    emptyModuleProvider: @escaping (Wallet) -> MVVMModule<CollectiblesEmptyViewController, CollectiblesEmptyModuleOutput, Void>
  ) -> MVVMModule<CollectiblesViewController, CollectiblesModuleOutput, Void> {
    let viewModel = CollectiblesViewModelImplementation(
      collectiblesController: collectiblesController,
      listModuleProvider: listModuleProvider,
      emptyModuleProvider: emptyModuleProvider
    )
    let viewController = CollectiblesViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
