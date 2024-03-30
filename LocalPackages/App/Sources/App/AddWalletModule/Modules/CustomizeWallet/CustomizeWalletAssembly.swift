import Foundation
import UIKit
import TKCore
import KeeperCore

struct CustomizeWalletAssembly {
  private init() {}
  static func module(name: String?,
                     tintColor: WalletTintColor?,
                     emoji: String?,
                     configurator: CustomizeWalletViewModelConfigurator) -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void> {
    let viewModel = CustomizeWalletViewModelImplementation(
      name: name,
      tintColor: tintColor,
      emoji: emoji,
      configurator: configurator
    )
    let viewController = CustomizeWalletViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
