import TKUIKit
import UIKit

final class SignerImportScanViewController: GenericViewViewController<SignerImportScanView> {
    private let viewModel: SignerImportScanViewModel
    private let scannerViewController: ScannerViewController

    init(
        viewModel: SignerImportScanViewModel,
        scannerViewController: ScannerViewController
    ) {
        self.viewModel = viewModel
        self.scannerViewController = scannerViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
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

private extension SignerImportScanViewController {
    func setupBindings() {
        viewModel.didUpdateOpenSignerButtonContent = { [weak customView] content in
            customView?.openSignerButton.configuration.content = content
        }
    }

    func setupViewActions() {
        customView.didTapOpenSignerButton = { [weak viewModel] in
            viewModel?.didTapOpenSigner()
        }
    }

    func setupScanner() {
        addChild(scannerViewController)
        customView.embedScannerView(scannerViewController.view)
        scannerViewController.didMove(toParent: self)
    }
}
