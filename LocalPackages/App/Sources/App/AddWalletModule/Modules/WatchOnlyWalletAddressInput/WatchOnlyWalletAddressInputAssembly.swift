import Foundation
import UIKit
import TKCore
import KeeperCore

struct WatchOnlyWalletAddressInputAssembly {
  private init() {}
  static func module(controller: WatchOnlyWalletAddressInputController) -> MVVMModule<UIViewController, WatchOnlyWalletAddressInputModuleOutput, Void> {
    let viewModel = WatchOnlyWalletAddressInputViewModelImplementation(controller: controller)
    let viewController = WatchOnlyWalletAddressInputViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
