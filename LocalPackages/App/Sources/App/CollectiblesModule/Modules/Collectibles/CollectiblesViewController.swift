import UIKit
import TKUIKit
import TKCoordinator

final class CollectiblesViewController: GenericViewViewController<CollectiblesView>, ScrollViewController {
  private let viewModel: CollectiblesViewModel
  
  private var listViewController: CollectiblesListViewController?
  
  init(viewModel: CollectiblesViewModel) {
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
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    listViewController?.customView.collectionView.contentInset.top = customView.navigationBarView.additionalInset
    listViewController?.customView.collectionView.verticalScrollIndicatorInsets.top = customView.navigationBarView.additionalInset
  }
  
  func scrollToTop() {
    listViewController?.scrollToTop()
  }
}

private extension CollectiblesViewController {
  func setupBindings() {
    viewModel.didUpdateListViewController = { [weak self] viewController in
      self?.setupListViewController(viewController: viewController)
    }
    
    viewModel.didUpdateIsConnecting = { [weak self] isConnecting in
      self?.customView.navigationBarView.isConnecting = isConnecting
    }
  }
  
  func setup() {
    customView.navigationBarView.title = "Collectibles"
  }
  
  func setupListViewController(viewController: CollectiblesListViewController) {
    self.listViewController?.removeFromParent()
    self.listViewController = viewController
    addChild(viewController)
    customView.addListContentView(view: viewController.view)
    viewController.didMove(toParent: self)
    
    customView.navigationBarView.scrollView = listViewController?.customView.collectionView
  }
}
