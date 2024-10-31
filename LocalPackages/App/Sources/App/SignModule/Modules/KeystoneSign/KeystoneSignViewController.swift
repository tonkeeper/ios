import UIKit
import TKUIKit

final class KeystoneSignViewController: GenericViewViewController<KeystoneSignView>, TKBottomSheetScrollContentViewController {
  private let viewModel: KeystoneSignViewModel
  private let scannerViewController: ScannerViewController
  
  private var cachedWidth: CGFloat?
  
  // MARK: - TKBottomSheetScrollContentViewController
  
  var scrollView: UIScrollView {
    customView.scrollView
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    customView.contentView.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                                                   withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
  }
  
  init(viewModel: KeystoneSignViewModel,
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

private extension KeystoneSignViewController {
  func setup() {
    customView.embedScannerView(scannerViewController.view)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
  }
}
