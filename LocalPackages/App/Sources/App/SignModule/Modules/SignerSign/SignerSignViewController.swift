import TKUIKit
import UIKit

final class SignerSignViewController: GenericViewViewController<SignerSignView>, TKBottomSheetScrollContentViewController {
    private let viewModel: SignerSignViewModel
    private let scannerViewController: ScannerViewController

    private var cachedWidth: CGFloat?

    // MARK: - TKBottomSheetScrollContentViewController

    var scrollView: UIScrollView {
        customView.scrollView
    }

    var didUpdateHeight: (() -> Void)?

    var headerConfiguration: TKBottomSheetHeaderConfiguration?

    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        customView.contentView.systemLayoutSizeFitting(
            CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    init(
        viewModel: SignerSignViewModel,
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
        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        customView.qrCodeView.layoutIfNeeded()
        if cachedWidth != customView.bounds.width {
            cachedWidth = customView.bounds.width
            viewModel.generateQRCodes(width: customView.qrCodeView.qrCodeImageViewContainer.bounds.width)
        }
    }
}

private extension SignerSignViewController {
    func setup() {
        addChild(scannerViewController)
        customView.embedScannerView(scannerViewController.view)
        scannerViewController.didMove(toParent: self)
    }

    func setupBindings() {
        viewModel.didUpdateModel = { [weak customView] model in
            customView?.configure(model: model)
        }
    }
}
