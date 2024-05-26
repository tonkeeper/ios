import UIKit
import TKUIKit

final class EmulateQRCodeViewController: GenericViewViewController<EmulateQRCodeView>, TKBottomSheetContentViewController {
  private let viewModel: EmulateQRCodeViewModel
  
  private var cachedWidth: CGFloat?
  
  // MARK: - Init
  
  init(viewModel: EmulateQRCodeViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  // MARK: - TKBottomSheetContentViewController

  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    customView.containerView.systemLayoutSizeFitting(
      CGSize(
        width: width,
        height: 0
      ),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    customView.qrCodeImageView.layoutIfNeeded()
    if cachedWidth != customView.bounds.width {
      cachedWidth = customView.bounds.width
      viewModel.generateQRCode(width: customView.qrCodeImageView.bounds.width)
    }
  }
}

// MARK: - Private

private extension EmulateQRCodeViewController {
  func setup() {}

  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] in
      customView?.configure(model: $0)
    }
  }
}
