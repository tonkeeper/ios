import UIKit
import SignerCore

struct MainModuleAssembly {
  private init() {}
  static func module(signerCoreAssembly: SignerCore.Assembly) -> Module<MainViewController, MainModuleOutput, Void> {
    let viewModel = MainViewModelImlementation(listController: signerCoreAssembly.walletKeysListController())
    let viewController = MainViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
