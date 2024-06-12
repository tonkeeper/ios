import UIKit
import TKUIKit
import TKLocalize

final class LedgerConnectViewController: GenericViewViewController<LedgerConnectView>, TKBottomSheetContentViewController {
  private let viewModel: LedgerConnectViewModel
  
  // MARK: - TKBottomSheetContentViewController
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(title: TKLocales.LedgerConnect.title)
  }
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    return 100
//    customView.containerView.systemLayoutSizeFitting(
//      CGSize(
//        width: width,
//        height: 0
//      ),
//      withHorizontalFittingPriority: .required,
//      verticalFittingPriority: .fittingSizeLevel
//    ).height
  }
  
  init(viewModel: LedgerConnectViewModel) {
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
}
