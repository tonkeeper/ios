import Foundation
import TKCore
import KeeperCore

struct SignerSignAssembly {
  private init() {}
  static func module(url: URL,
                     wallet: Wallet,
                     assembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<SignerSignViewController, SignerSignModuleOutput, SignerSignModuleInput> {
    
    let scannerModule = ScannerModule(
      dependencies: ScannerModule.Dependencies(
        coreAssembly: coreAssembly,
        scannerAssembly: assembly.scannerAssembly()
      )
    ).createScannerModule(
      configurator: SignerSignControllerConfigurator(),
      uiConfiguration: ScannerUIConfiguration(
        title: nil,
        subtitle: nil,
        isFlashlightVisible: false
      )
    )
    
    let viewModel = SignerSignViewModelImplementation(
      signerSignController: assembly.signerSignController(url: url, wallet: wallet),
      qrCodeGenerator: QRCodeGeneratorImplementation(),
      scannerOutput: scannerModule.output
    )
    let viewController = SignerSignViewController(viewModel: viewModel, scannerViewController: scannerModule.view)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
