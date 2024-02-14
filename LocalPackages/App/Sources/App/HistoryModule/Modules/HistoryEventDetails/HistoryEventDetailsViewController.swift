import UIKit
import TKUIKit

final class HistoryEventDetailsViewController: GenericViewViewController<HistoryEventDetailsView>, TKBottomSheetScrollContentViewController {
  var scrollView: UIScrollView {
    modalCardViewController.scrollView
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  private let viewModel: HistoryEventDetailsViewModel
  
  private let modalCardViewController = TKModalCardViewController()
  
  init(viewModel: HistoryEventDetailsViewModel) {
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
}

private extension HistoryEventDetailsViewController {
  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak self] configuration in
      self?.modalCardViewController.configuration = configuration
      self?.didUpdateHeight?()
    }
  }
  
  func setup() {
    setupModalContent()
  }
  
  func setupModalContent() {
    customView.embedContent(modalCardViewController.view)
//    modalCardViewController.didUpdateHeight = { [weak self] in
////      self?.didUpdateHeight?()
//    }
  }
}
