import Foundation
import UIKit
import TKCore
import KeeperCore

struct CustomizeWalletAssembly {
  private init() {}
  static func module(wallet: Wallet? = nil, configurator: CustomizeWalletViewModelConfigurator) -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void> {
    let viewModel = CustomizeWalletViewModelImplementation(
      wallet: wallet,
      configurator: configurator
    )
    let viewController = CustomizeWalletViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
