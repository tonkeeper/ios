import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class BrowserViewController: GenericViewViewController<BrowserView>, ScrollViewController {
  private let viewModel: BrowserViewModel
  
  private weak var selectedViewController: ScrollViewController?
  
  private let exploreViewController: BrowserExploreViewController
  private let connectedViewController: BrowserConnectedViewController
  
  init(viewModel: BrowserViewModel,
       exploreViewController: BrowserExploreViewController,
       connectedViewController: BrowserConnectedViewController) {
    self.viewModel = viewModel
    self.exploreViewController = exploreViewController
    self.connectedViewController = connectedViewController
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
    viewModel.viewWillAppear()
  }
  
  func scrollToTop() {
    selectedViewController?.scrollToTop()
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
    connectedViewController.setListContentInsets(
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
    
    addChild(connectedViewController)
    customView.embedConnectedView(connectedViewController.customView)
    connectedViewController.didMove(toParent: self)
    
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

    viewModel.didUpdateRightHeaderButton = { [weak customView] model in
      customView?.headerView.configureRightButton(model: model)
    }
  }
  
  func showExplore() {
    customView.exploreContainer.isHidden = false
    customView.connectedContainer.isHidden = true
    selectedViewController = exploreViewController
  }
  
  func showConnected() {
    customView.connectedContainer.isHidden = false
    customView.exploreContainer.isHidden = true
    selectedViewController = connectedViewController
  }
  
  @objc
  func didTapSearchBar() {
    viewModel.didTapSearchBar()
  }
}

