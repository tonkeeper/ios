import Foundation
import TKCore

struct WalletContainerAssembly {
  private init() {}
  static func module() -> MVVMModule<WalletContainerViewController, WalletContainerViewModel, Void> {
    let viewModel = WalletContainerViewModelImplementation()
    let viewController = WalletContainerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
