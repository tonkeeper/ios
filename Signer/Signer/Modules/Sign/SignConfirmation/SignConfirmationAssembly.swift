import UIKit
import SignerCore

struct SignConfirmationAssembly {
  private init() {}
  static func module(signerCoreAssembly: SignerCore.Assembly, model: TonSignModel, walletKey: WalletKey) -> Module<SignConfirmationViewController, SignConfirmationModuleOutput, Void> {
    let viewModel = SignConfirmationViewModelImplementation(
      controller: signerCoreAssembly.signConfirmationController(
        model: model,
        walletKey: walletKey
      )
    )
    let viewController = SignConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
