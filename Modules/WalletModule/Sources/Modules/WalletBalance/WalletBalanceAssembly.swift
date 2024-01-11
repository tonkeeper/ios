import Foundation
import TKCore

struct WalletBalanceAssembly {
  private init() {}
  static func module() -> MVVMModule<WalletBalanceViewController, WalletBalanceViewModel, Void> {
    let viewModel = WalletBalanceViewModelImplementation()
    let viewController = WalletBalanceViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
