import Foundation
import TKCore
import KeeperCore
import URKit

struct KeystoneSignAssembly {
  private init() {}
  static func module(transaction: UR,
                     wallet: Wallet,
                     assembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<KeystoneSignViewController, KeystoneSignModuleOutput, KeystoneSignModuleInput> {
    
    let scannerModule = ScannerModule(
      dependencies: ScannerModule.Dependencies(
        coreAssembly: coreAssembly,
        scannerAssembly: assembly.scannerAssembly()
      )
    ).createScannerModule(
      configurator: KeystoneSignControllerConfigurator(),
      uiConfiguration: ScannerUIConfiguration(
        title: nil,
        subtitle: nil,
        isFlashlightVisible: false
      )
    )
    
    let viewModel = KeystoneSignViewModelImplementation(
      keystoneSignController: assembly.keystoneSignController(transaction: transaction, wallet: wallet),
      qrCodeGenerator: QRCodeGeneratorImplementation(),
      scannerOutput: scannerModule.output
    )
    let viewController = KeystoneSignViewController(viewModel: viewModel, scannerViewController: scannerModule.view)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
