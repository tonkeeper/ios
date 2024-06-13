import UIKit
import TKUIKit
import TKLocalize

final class LedgerConfirmViewController: GenericViewViewController<LedgerConfirmView>, TKBottomSheetContentViewController {
  private let viewModel: LedgerConfirmViewModel
  
  // MARK: - TKBottomSheetContentViewController
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(title: TKLocales.LedgerConfirm.title)
  }
  
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
  
  init(viewModel: LedgerConfirmViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      self?.customView.configure(model: model)
    }
  }
}
