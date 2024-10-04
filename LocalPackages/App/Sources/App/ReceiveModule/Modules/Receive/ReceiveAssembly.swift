import Foundation
import TKCore
import KeeperCore

struct ReceiveAssembly {
  private init() {}
  static func module(token: Token,
                     wallet: Wallet,
                     qrCodeGenerator: QRCodeGenerator) -> MVVMModule<ReceiveViewController, ReceiveModuleOutput, Void> {
    let viewModel = ReceiveViewModelImplementation(
      token: token,
      wallet: wallet,
      deeplinkGenerator: DeeplinkGenerator(),
      qrCodeGenerator: qrCodeGenerator
    )
    let viewController = ReceiveViewController(viewModel: viewModel)
    return MVVMModule(view: viewController, output: viewModel, input: Void())
  }
}
