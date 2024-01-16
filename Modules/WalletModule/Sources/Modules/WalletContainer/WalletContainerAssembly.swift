import Foundation
import TKCore
import KeeperCore

struct WalletContainerAssembly {
  private init() {}
  static func module(childModuleProvider: WalletContainerViewModelChildModuleProvider,
                     walletMainController: WalletMainController) -> MVVMModule<WalletContainerViewController, WalletContainerModuleOutput, Void> {
    let viewModel = WalletContainerViewModelImplementation(
      childModuleProvider: childModuleProvider,
      walletMainController: walletMainController
    )
    let viewController = WalletContainerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
