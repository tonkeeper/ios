import Foundation
import TKCore
import KeeperCore

struct WalletBalanceAssembly {
  private init() {}
  static func module(walletBalanceController: WalletBalanceController) -> MVVMModule<WalletBalanceViewController, WalletBalanceViewModel, Void> {
    let viewModel = WalletBalanceViewModelImplementation(walletBalanceController: walletBalanceController)
    let viewController = WalletBalanceViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
