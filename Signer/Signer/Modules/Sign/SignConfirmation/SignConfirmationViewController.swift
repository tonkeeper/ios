import UIKit
import TKUIKit

final class SignConfirmationViewController: GenericViewViewController<SignConfirmationView>, TKBottomSheetScrollContentViewController {
  private let viewModel: SignConfirmationViewModel
  
  // MARK: - Init
  
  init(viewModel: SignConfirmationViewModel) {
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
  
  // MARK: - TKBottomSheetScrollContentViewController
  
  var scrollView: UIScrollView {
    customView.scrollView
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    customView.containerView.systemLayoutSizeFitting(CGSize(width: width, height: 0)).height
  }
}

// MARK: - Private

private extension SignConfirmationViewController {
  func setup() {
    customView.auditButton.addAction(UIAction(handler: { [weak self] _ in
      self?.customView.showBocView()
      self?.didUpdateHeight?()
    }), for: .touchUpInside)
    
    customView.swipeControl.didConfirm = { [weak viewModel] in
      viewModel?.didConfirmTransaction()
    }
  }

  func setupBindings() {

    viewModel.didUpdateHeader = { [weak self] title, subtitle in
      self?.didUpdatePullCardHeaderItem?(TKUIKit.TKPullCardHeaderItem(title: title, subtitle: subtitle))
    }
    
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didCancel = { [weak customView] in
      customView?.swipeControl.reset()
      
    }
  }
}
