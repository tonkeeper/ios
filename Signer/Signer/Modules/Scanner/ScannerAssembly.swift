import UIKit
import SignerCore

struct ScannerAssembly {
  private init() {}
  static func module(signerCoreAssembly: SignerCore.Assembly,
                     urlOpener: URLOpener,
                     title: String?,
                     subtitle: String? = nil) -> Module<ScannerViewController, ScannerViewModuleOutput, Void> {
    let viewModel = ScannerViewModelImplementation(
      urlOpener: urlOpener,
      scannerController: signerCoreAssembly.scannerController(),
      title: title,
      subtitle: subtitle
    )
    let viewController = ScannerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
