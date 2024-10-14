import UIKit
import TKUIKit
import TKCoordinator

final class HistoryContainerViewController: GenericViewViewController<HistoryContainerView>, ScrollViewController {
  private let viewModel: HistoryContainerViewModel
  
  var historyViewController: HistoryViewController? {
    didSet {
      oldValue?.willMove(toParent: nil)
      customView.setContentView(nil)
      oldValue?.removeFromParent()
      
      setupHistoryViewController()
    }
  }
  
  init(viewModel: HistoryContainerViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    viewModel.viewDidLoad()
  }
  
  func scrollToTop() {
    historyViewController?.scrollToTop()
  }
  
  private func setup() {
    setupHistoryViewController()
  }
  
  private func setupHistoryViewController() {
    guard isViewLoaded, let historyViewController else { return }
    addChild(historyViewController)
    customView.setContentView(historyViewController.view)
    historyViewController.didMove(toParent: self)
  }
}
