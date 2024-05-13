import UIKit
import TKCore
import KeeperCore

struct ScannerAssembly {
  private init() {}
  static func module(scannerController: ScannerController,
                     urlOpener: URLOpener,
                     uiConfiguration: ScannerUIConfiguration) -> MVVMModule<ScannerViewController, ScannerViewModuleOutput, Void> {
    let viewModel = ScannerViewModelImplementation(
      urlOpener: urlOpener,
      scannerController: scannerController,
      uiConfiguration: uiConfiguration
    )
    let viewController = ScannerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
