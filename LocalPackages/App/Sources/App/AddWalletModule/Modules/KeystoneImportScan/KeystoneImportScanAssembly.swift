import Foundation
import UIKit
import TKCore
import KeeperCore
import TKLocalize

struct KeystoneImportScanAssembly {
  private init() {}
  static func module(scannerAssembly: KeeperCore.ScannerAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<UIViewController, KeystoneImportScanModuleOutput, Void> {
    let scannerModule = ScannerAssembly.module(
      scannerController: scannerAssembly.scannerController(
        configurator: KeystoneScannerControllerConfigurator()
      ),
      urlOpener: coreAssembly.urlOpener(),
      uiConfiguration: ScannerUIConfiguration(
        title: TKLocales.Scanner.title,
        subtitle: TKLocales.Keystone.Scan.subtitle,
        isFlashlightVisible: true
      )
    )
    
    let viewModel = KeystoneImportScanViewModelImplementation(
      urlOpener: coreAssembly.urlOpener(),
      scannerViewModuleOutput: scannerModule.output
    )
    let viewController = KeystoneImportScanViewController(viewModel: viewModel, scannerViewController: scannerModule.view)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
