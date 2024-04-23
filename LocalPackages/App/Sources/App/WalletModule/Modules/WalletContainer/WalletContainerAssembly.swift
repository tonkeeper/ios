import Foundation
import TKCore
import KeeperCore

struct WalletContainerAssembly {
  private init() {}
  static func module(walletBalanceModule: WalletBalanceModule,
                     walletMainController: WalletMainController) -> MVVMModule<WalletContainerViewController, WalletContainerModuleOutput, Void> {
    let viewModel = WalletContainerViewModelImplementation(
      walletBalanceModuleInput: walletBalanceModule.input,
      walletMainController: walletMainController
    )
    let viewController = WalletContainerViewController(
      viewModel: viewModel,
      walletBalanceViewController: walletBalanceModule.view
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
