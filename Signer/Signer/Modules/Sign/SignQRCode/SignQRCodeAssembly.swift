import UIKit
import SignerCore

struct SignQRCodeAssembly {
  private init() {}
  static func module(signerCoreAssembly: SignerCore.Assembly, 
                     url: URL, 
                     walletKey: WalletKey,
                     hexBody: String) -> Module<SignQRCodeViewController, SignQRCodeModuleOutput, Void> {
    let viewModel = SignQRCodeViewModelImplementation(
      qrCodeGenerator: QRCodeGeneratorImplementation(),
      signQRController: signerCoreAssembly.signQRController(
        hexBody: hexBody,
        walletKey: walletKey,
        url: url
      )
    )
    let viewController = SignQRCodeViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
