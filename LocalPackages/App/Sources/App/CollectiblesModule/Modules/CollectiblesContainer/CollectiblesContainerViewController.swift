import UIKit
import TKUIKit
import TKCoordinator

final class CollectiblesContainerViewController: GenericViewViewController<CollectiblesContainerView>, ScrollViewController {
  private let viewModel: CollectiblesContainerViewModel
  
  // MARK: - ScrollViewController
  func scrollToTop() {
    collectiblesViewController?.scrollToTop()
  }
  
  
  var collectiblesViewController: CollectiblesViewController? {
    didSet {
      oldValue?.willMove(toParent: nil)
      customView.setContentView(nil)
      oldValue?.removeFromParent()
      
      setupCollectiblesViewController()
    }
  }
  
  init(viewModel: CollectiblesContainerViewModel) {
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
  
  private func setup() {
    setupCollectiblesViewController()
  }
  
  private func setupCollectiblesViewController() {
    guard isViewLoaded, let collectiblesViewController else { return }
    addChild(collectiblesViewController)
    customView.setContentView(collectiblesViewController.view)
    collectiblesViewController.didMove(toParent: self)
  }
}
