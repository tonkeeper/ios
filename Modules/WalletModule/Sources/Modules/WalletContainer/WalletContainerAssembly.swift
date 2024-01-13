import Foundation
import TKCore

struct WalletContainerAssembly {
  private init() {}
  static func module(childModuleProvider: WalletContainerViewModelChildModuleProvider) -> MVVMModule<WalletContainerViewController, WalletContainerViewModel, Void> {
    let viewModel = WalletContainerViewModelImplementation(childModuleProvider: childModuleProvider)
    let viewController = WalletContainerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
