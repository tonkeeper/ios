import UIKit
import SignerCore

struct EmulateQRCodeAssembly {
  private init() {}
  static func module(signerCoreAssembly: SignerCore.Assembly, 
                     url: URL) -> Module<EmulateQRCodeViewController, EmulateQRCodeModuleOutput, Void> {
    let viewModel = EmulateQRCodeViewModelImplementation(
      url: url,
      qrCodeGenerator: QRCodeGeneratorImplementation()
    )
    let viewController = EmulateQRCodeViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
