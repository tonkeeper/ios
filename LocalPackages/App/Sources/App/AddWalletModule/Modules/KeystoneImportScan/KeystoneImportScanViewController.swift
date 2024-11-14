import UIKit
import TKUIKit

final class KeystoneImportScanViewController: GenericViewViewController<KeystoneImportScanView> {
  private let viewModel: KeystoneImportScanViewModel
  private let scannerViewController: ScannerViewController
  
  init(viewModel: KeystoneImportScanViewModel,
       scannerViewController: ScannerViewController) {
    self.viewModel = viewModel
    self.scannerViewController = scannerViewController
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupScanner()
    setupBindings()
    setupViewActions()
    viewModel.viewDidLoad()
  }
}

private extension KeystoneImportScanViewController {
  func setupBindings() {
  }

  func setupViewActions() {
    customView.didTapOpenKeystoneButton = { [weak viewModel] in
      viewModel?.didTapOpenKeystone()
    }
  }
  
  func setupScanner() {
    addChild(scannerViewController)
    customView.embedScannerView(scannerViewController.view)
    scannerViewController.didMove(toParent: self)
  }
}
