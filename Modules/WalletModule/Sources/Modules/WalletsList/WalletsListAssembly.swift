import Foundation
import TKCore
import KeeperCore

struct WalletsListAssembly {
  private init() {}
  static func module(walletListController: WalletListController) -> MVVMModule<WalletsListViewController, WalletsListModuleOutput, Void> {
    let viewModel = WalletsListViewModelImplementation(walletListController: walletListController)
    
    let viewController = WalletsListViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
