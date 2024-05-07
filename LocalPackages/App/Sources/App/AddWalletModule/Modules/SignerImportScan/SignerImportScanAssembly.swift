import Foundation
import UIKit
import TKCore
import KeeperCore
import TKLocalize

struct SignerImportScanAssembly {
  private init() {}
  static func module(scannerAssembly: KeeperCore.ScannerAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<UIViewController, SignerImportScanModuleOutput, Void> {
    let scannerModule = ScannerAssembly.module(
      scannerController: scannerAssembly.scannerController(
        configurator: SignerScannerControllerConfigurator()
      ),
      urlOpener: coreAssembly.urlOpener(),
      uiConfiguration: ScannerUIConfiguration(
        title: TKLocales.Scanner.title,
        subtitle: TKLocales.Signer.Scan.subtitle,
        isFlashlightVisible: true
      )
    )
    
    let viewModel = SignerImportScanViewModelImplementation(
      urlOpener: coreAssembly.urlOpener(),
      signerScanController: scannerAssembly.signerScanController(),
      scannerViewModuleOutput: scannerModule.output
    )
    let viewController = SignerImportScanViewController(viewModel: viewModel, scannerViewController: scannerModule.view)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
