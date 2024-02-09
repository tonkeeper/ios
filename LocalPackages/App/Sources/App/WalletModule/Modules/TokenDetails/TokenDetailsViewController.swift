import UIKit
import TKUIKit

final class TokenDetailsViewController: GenericViewViewController<TokenDetailsView> {
  private let viewModel: TokenDetailsViewModel
  private let listContentViewController: TokenDetailsListContentViewController
  
  private let headerViewController = TokenDetailsHeaderViewController()
  private let titleView = TokenDetailsTitleView()
  
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
}

private extension TokenDetailsViewController {
  func setupBindings() {
    viewModel.didUpdateTitleView = { [weak self] titleModel in
      self?.titleView.configure(model: titleModel)
    }
    
    viewModel.didUpdateInformationView = { [weak self] model in
      self?.headerViewController.informationView.configure(model: model)
    }
    
    viewModel.didUpdateChartViewController = { [weak self] viewController in
      self?.headerViewController.embedChartViewController(viewController)
    }
  }
  
  func setup() {
    customView.navigationBar.setItems([navigationItem], animated: false)
    customView.navigationBar.topItem?.titleView = titleView
    navigationItem.setupBackButton { [weak self] in
      self?.navigationController?.popViewController(animated: true)
    }
    
    setupListContent()
  }
  
  func setupListContent() {
    addChild(listContentViewController)
    customView.embedListView(listContentViewController.view)
    listContentViewController.didMove(toParent: self)
    listContentViewController.setHeaderViewController(headerViewController)
  }
}
