import Foundation
import TKCore
import KeeperCore

struct WalletContainerAssembly {
  private init() {}
  static func module(walletBalanceModule: WalletBalanceModule,
                     walletsStore: WalletsStoreV2) -> MVVMModule<WalletContainerViewController, WalletContainerModuleOutput, Void> {
    let viewModel = WalletContainerViewModelImplementation(
      walletsStore: walletsStore
    )
    let viewController = WalletContainerViewController(
      viewModel: viewModel,
      walletBalanceViewController: walletBalanceModule.view
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
