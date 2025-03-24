import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class CollectiblesViewController: GenericViewViewController<CollectiblesView>, ScrollViewController {

  private let viewModel: CollectiblesViewModel
  private let collectiblesListViewController: CollectiblesListViewController
  
  init(viewModel: CollectiblesViewModel,
       collectiblesListViewController: CollectiblesListViewController) {
    self.viewModel = viewModel
    self.collectiblesListViewController = collectiblesListViewController
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
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    customView.navigationBar.layoutIfNeeded()
    collectiblesListViewController.topInset = customView.navigationBar.bounds.height
  }
  
  func scrollToTop() {
    collectiblesListViewController.scrollToTop()
  }
}

private extension CollectiblesViewController {
  func setup() {
    configureNavigationBar()
    setupListViewController()
    setupBindings()
  }

  func configureNavigationBar() {
    customView.navigationBar.title = TKLocales.Collectibles.title
    customView.navigationBar.scrollView = collectiblesListViewController.customView.collectionView
  }

  func setupBindings() {
    viewModel.didUpdateIsLoading = { [weak self] isLoading in
      self?.customView.navigationBar.isLoading = isLoading
    }

    viewModel.didUpdateNavigationBarButtons = { [weak self] buttons in
      self?.customView.navigationBar.rightButtonItems = buttons
    }
  }
  
  func setupListViewController() {
    addChild(collectiblesListViewController)
    customView.listContainerView.addSubview(collectiblesListViewController.view)
    collectiblesListViewController.didMove(toParent: self)
    
    collectiblesListViewController.view.snp.makeConstraints { make in
      make.edges.equalTo(customView.listContainerView)
    }
    
    collectiblesListViewController.didScroll = { [weak self] scrollView in
      guard let self else { return }
      let refreshControlHeight: CGFloat = {
        guard let refreshControl = scrollView.refreshControl else { return 0 }
        return refreshControl.isRefreshing ? refreshControl.bounds.height : 0
      }()
      let offset = min(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top - refreshControlHeight)
      let navigationBarOffset = min(offset, customView.navigationBar.bounds.height)
      customView.navigationBar.transform = CGAffineTransform(translationX: 0, y: -navigationBarOffset)  
    }
  }
}
