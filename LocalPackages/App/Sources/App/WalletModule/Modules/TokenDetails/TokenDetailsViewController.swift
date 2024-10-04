import UIKit
import TKUIKit

final class TokenDetailsViewController: GenericViewViewController<TokenDetailsView> {
  private let viewModel: TokenDetailsViewModel
  private let listContentViewController: TokenDetailsListContentViewController
  
  private let headerViewController = TokenDetailsHeaderViewController()
  
  init(viewModel: TokenDetailsViewModel,
       listContentViewController: TokenDetailsListContentViewController) {
    self.viewModel = viewModel
    self.listContentViewController = listContentViewController
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
    
    customView.navigationBar.layoutIfNeeded()
    listContentViewController.scrollView.contentInset.top = customView.navigationBar.bounds.height
    listContentViewController.scrollView.contentInset.bottom = customView.safeAreaInsets.bottom + 16
  }
}

private extension TokenDetailsViewController {
  func setupBindings() {
    viewModel.didUpdateTitleView = { [weak self] model in
      self?.customView.titleView.configure(model: model)
    }
    
    viewModel.didUpdateInformationView = { [weak self] model in
      self?.headerViewController.informationView.configure(model: model)
    }
    
    viewModel.didUpdateButtonsView = { [weak self] model in
      self?.headerViewController.buttonsView.configure(model: model)
    }
    
    viewModel.didUpdateChartViewController = { [weak self] viewController in
      self?.headerViewController.embedChartViewController(viewController)
    }
  }
  
  func setup() {
    setupNavigationBar()

    listContentViewController.scrollView.contentInsetAdjustmentBehavior = .never
    
    setupListContent()
  }
  
  private func setupNavigationBar() {
    guard let navigationController,
          !navigationController.viewControllers.isEmpty else {
      return
    }
    customView.navigationBar.leftViews = [
      TKUINavigationBar.createBackButton {
        navigationController.popViewController(animated: true)
      }
    ]
    
    customView.navigationBar.rightViews = [
      TKUINavigationBar.createMoreButton { view in
        let item = TKPopupMenuItem(
          title: "View details",
          icon: .TKUIKit.Icons.Size16.globe,
          selectionHandler: { [weak self] in
            self?.viewModel.didTapOpenDetails()
          }
        )
        TKPopupMenuController.show(
          sourceView: view,
          position: .topRight,
          width: 0,
          items: [item],
          isSelectable: false,
          selectedIndex: nil)
      }
    ]
  }
  
  func setupListContent() {
    addChild(listContentViewController)
    customView.embedListView(listContentViewController.view)
    listContentViewController.didMove(toParent: self)
    listContentViewController.setHeaderViewController(headerViewController)
    customView.navigationBar.scrollView = listContentViewController.scrollView
  }
}
