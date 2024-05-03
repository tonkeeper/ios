import UIKit
import SignerCore

struct TonConnectConfirmationAssembly {
  private init() {}
  static func module() -> Module<TonConnectConfirmationViewController, TonConnectConfirmationModuleOutput, Void> {
    let viewModel = TonConnectConfirmationViewModelImplementation()
    let viewController = TonConnectConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
