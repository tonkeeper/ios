import UIKit
import TKQRCode
import SignerCore

struct KeyDetailsModuleAssembly {
  private init() {}
  static func module(walletKey: WalletKey, signerCoreAssembly: SignerCore.Assembly) -> Module<KeyDetailsViewController, KeyDetailsModuleOutput, Void> {
    let viewModel = KeyDetailsViewModelImplementation(
      keyDetailsController: signerCoreAssembly.walletKeyDetailsController(
        walletKey: walletKey
      ),
      qrCodeGenerator: TKQRCode.qrCodeGenerator
    )
    let viewController = KeyDetailsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
