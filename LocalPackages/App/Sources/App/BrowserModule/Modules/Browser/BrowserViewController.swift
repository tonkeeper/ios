import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class BrowserViewController: GenericViewViewController<BrowserView>, ScrollViewController {
  private let viewModel: BrowserViewModel
  
  private let exploreViewController: BrowserExploreViewController
  
  init(viewModel: BrowserViewModel,
       exploreViewController: BrowserExploreViewController) {
    self.viewModel = viewModel
    self.exploreViewController = exploreViewController
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
  
  func scrollToTop() {
    
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    customView.headerView.layoutIfNeeded()
    exploreViewController.setListContentInsets(
      UIEdgeInsets(
        top: customView.headerView.bounds.height,
        left: 0,
        bottom: customView.safeAreaInsets.bottom + customView.searchBar.bounds.height,
        right: 0
      )
    )
  }
}

// MARK: - Private

private extension BrowserViewController {
  func setup() {
    addChild(exploreViewController)
    customView.embedExploreView(exploreViewController.customView)
    exploreViewController.didMove(toParent: self)
    
    customView.searchBar.addGestureRecognizer(
      UITapGestureRecognizer(
        target: self,
        action: #selector(
          didTapSearchBar
        )
      )
    )
  }
  
  func setupBindings() {
    viewModel.didUpdateSegmentedControl = { [weak customView] model in
      customView?.headerView.segmentedControlView.configure(model: model)
    }
    
    viewModel.didSelectExplore = { [weak self] in
      self?.showExplore()
      
    }
    
    viewModel.didSelectConnected = { [weak self] in
      self?.showConnected()
    }
  }
  
  func showExplore() {
    customView.exploreContainer.isHidden = false
    customView.connectedContainer.isHidden = true
  }
  
  func showConnected() {
    customView.connectedContainer.isHidden = false
    customView.exploreContainer.isHidden = true
  }
  
  @objc
  func didTapSearchBar() {
    viewModel.didTapSearchBar()
  }
}

