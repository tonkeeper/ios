import Foundation
import TKCore
import KeeperCore

struct ReceiveAssembly {
  private init() {}
  static func module(receiveController: ReceiveController,
                     qrCodeGenerator: QRCodeGenerator) -> MVVMModule<ReceiveViewController, ReceiveModuleOutput, Void> {
    let viewModel = ReceiveViewModelImplementation(
      receiveController: receiveController,
      qrCodeGenerator: qrCodeGenerator
    )
    let viewController = ReceiveViewController(viewModel: viewModel)
    return MVVMModule(view: viewController, output: viewModel, input: Void())
  }
}
