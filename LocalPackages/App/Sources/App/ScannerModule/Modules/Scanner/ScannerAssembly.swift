import UIKit
import TKCore
import KeeperCore

struct ScannerAssembly {
  private init() {}
  static func module(scannerController: ScannerController,
                     urlOpener: URLOpener,
                     title: String?,
                     subtitle: String? = nil) -> MVVMModule<ScannerViewController, ScannerViewModuleOutput, Void> {
    let viewModel = ScannerViewModelImplementation(
      urlOpener: urlOpener,
      scannerController: scannerController,
      title: title,
      subtitle: subtitle
    )
    let viewController = ScannerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
