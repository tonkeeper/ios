import Foundation
import UIKit
import TKCore
import KeeperCore

struct ChooseWalletToAddAssembly {
  private init() {}
  static func module(controller: ChooseWalletsController) -> MVVMModule<UIViewController, ChooseWalletToAddModuleOutput, Void> {
    let viewModel = ChooseWalletToAddViewModelImplementation(controller: controller)
    let viewController = ChooseWalletToAddViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
