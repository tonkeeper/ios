import UIKit
import TKUIKit

final class SwapConfirmationViewController: GenericViewViewController<SwapConfirmationView>, TKBottomSheetScrollContentViewController {
  
  private let viewModel: SwapConfirmationViewModel
  
  init(viewModel: SwapConfirmationViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.viewDidLoad()
  }

  // MARK: - TKPullCardScrollableContent
  
  var scrollView: UIScrollView {
    customView.scrollView
  }
  var didUpdateHeight: (() -> Void)?
  var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(title: "Confirm Swap")
  }
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    scrollView.contentSize.height
  }
}
