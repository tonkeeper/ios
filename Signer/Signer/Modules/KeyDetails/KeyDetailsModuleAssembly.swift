import UIKit
import SignerCore

struct KeyDetailsModuleAssembly {
  private init() {}
  static func module(walletKey: WalletKey, signerCoreAssembly: SignerCore.Assembly) -> Module<KeyDetailsViewController, KeyDetailsModuleOutput, Void> {
    let viewModel = KeyDetailsViewModelImplementation(
      keyDetailsController: signerCoreAssembly.walletKeyDetailsController(
        walletKey: walletKey
      )
    )
    let viewController = KeyDetailsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
