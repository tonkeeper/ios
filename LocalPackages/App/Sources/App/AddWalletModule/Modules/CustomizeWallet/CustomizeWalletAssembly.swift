import Foundation
import UIKit
import TKCore

struct CustomizeWalletAssembly {
  private init() {}
  static func module() -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void> {
    let viewModel = CustomizeWalletViewModelImplementation()
    let viewController = CustomizeWalletViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
