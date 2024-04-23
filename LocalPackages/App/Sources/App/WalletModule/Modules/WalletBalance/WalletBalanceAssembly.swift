import Foundation
import TKCore
import KeeperCore

typealias WalletBalanceModule = MVVMModule<WalletBalanceViewController, WalletBalanceModuleOutput, WalletBalanceModuleInput>

struct WalletBalanceAssembly {
  private init() {}
  static func module(walletBalanceController: WalletBalanceController) -> WalletBalanceModule {
    let viewModel = WalletBalanceViewModelImplementation(walletBalanceController: walletBalanceController)
    let viewController = WalletBalanceViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
