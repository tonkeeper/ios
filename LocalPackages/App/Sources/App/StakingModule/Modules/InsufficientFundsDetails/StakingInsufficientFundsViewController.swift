import UIKit
import TKUIKit
import TKCore

final class StakingInsufficientFundsViewController:
  GenericViewViewController<StakingInsufficientFundsView>, TKBottomSheetScrollContentViewController {
  var scrollView: UIScrollView {
    modalCardViewController.scrollView
  }
  
  var didUpdateHeight: (() -> Void)?
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  private let viewModel: StakingInsufficientFundsViewModel
  private let modalCardViewController = TKModalCardViewController()
  
  init(viewModel: StakingInsufficientFundsViewModel) {
    self.viewModel = viewModel
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
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    modalCardViewController.calculateHeight(withWidth: width)
  }
}

// MARK: - Private methods

private extension StakingInsufficientFundsViewController {
  func setup() {
    customView.embedContent(modalCardViewController.view)
  }
  
  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak self] configuration in
      self?.modalCardViewController.configuration = configuration
      self?.didUpdateHeight?()
    }
  }
}
